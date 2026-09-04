-- Sprout: memory & circles schema
-- Run this once in Supabase Dashboard > SQL Editor on a fresh project.

-- ─── profiles ────────────────────────────────────────────────────────────
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "profiles are readable by any signed-in user"
  on profiles for select
  to authenticated
  using (true);

create policy "users can update their own profile"
  on profiles for update
  to authenticated
  using (auth.uid() = id);

-- ─── circles ─────────────────────────────────────────────────────────────
-- created_by references profiles (not auth.users directly) so PostgREST
-- can embed the creator's name/avatar in circle queries. Safe because
-- every auth.users row gets a profiles row via the trigger below.
create table if not exists circles (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  cover_image_url text,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table circles enable row level security;

-- ─── circle_members ──────────────────────────────────────────────────────
create table if not exists circle_members (
  circle_id uuid not null references circles(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (circle_id, user_id)
);

alter table circle_members enable row level security;

-- Helper: is the current user a member of a given circle?
create or replace function is_circle_member(target_circle_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from circle_members
    where circle_id = target_circle_id
      and user_id = auth.uid()
  );
$$;

-- circles policies (defined after the helper function above)
create policy "members can view their circles"
  on circles for select
  to authenticated
  using (is_circle_member(id));

create policy "any signed-in user can create a circle"
  on circles for insert
  to authenticated
  with check (auth.uid() = created_by);

create policy "circle admins can update their circle"
  on circles for update
  to authenticated
  using (
    exists (
      select 1 from circle_members
      where circle_id = id and user_id = auth.uid() and role = 'admin'
    )
  );

-- circle_members policies
create policy "members can view membership of their circles"
  on circle_members for select
  to authenticated
  using (is_circle_member(circle_id));

create policy "circle admins (or the creator, at creation time) can add members"
  on circle_members for insert
  to authenticated
  with check (
    -- the creator adding themselves right after creating the circle
    (user_id = auth.uid() and exists (
      select 1 from circles where id = circle_id and created_by = auth.uid()
    ))
    or
    -- an existing admin inviting someone else
    exists (
      select 1 from circle_members cm
      where cm.circle_id = circle_id and cm.user_id = auth.uid() and cm.role = 'admin'
    )
  );

-- ─── memories ────────────────────────────────────────────────────────────
create table if not exists memories (
  id uuid primary key default gen_random_uuid(),
  circle_id uuid not null references circles(id) on delete cascade,
  uploaded_by uuid not null references profiles(id) on delete cascade,
  image_url text not null,
  caption text,
  created_at timestamptz not null default now()
);

alter table memories enable row level security;

create policy "members can view memories in their circles"
  on memories for select
  to authenticated
  using (is_circle_member(circle_id));

create policy "members can add memories to their circles"
  on memories for insert
  to authenticated
  with check (is_circle_member(circle_id) and uploaded_by = auth.uid());

-- ─── storage ─────────────────────────────────────────────────────────────
-- Bucket is PRIVATE — photos are only ever served via short-lived signed
-- URLs generated in the app (see MemoriesRepository), never a public link.
-- RLS below still governs who's even allowed to request a signed URL.

insert into storage.buckets (id, name, public)
values ('memories', 'memories', false)
on conflict (id) do update set public = false;

create policy "circle members can upload to their circle's folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'memories'
    and is_circle_member((storage.foldername(name))[1]::uuid)
  );

create policy "circle members can read their circle's photos"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'memories'
    and is_circle_member((storage.foldername(name))[1]::uuid)
  );

-- ─── auto-create profile on signup (belt-and-suspenders with AuthService) ──
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ─── notifications ───────────────────────────────────────────────────────
-- Only two event types are generated for now — new memory in a circle you're
-- in, and someone joining a circle you're in. Reactions/comments/mentions
-- aren't tracked yet (no tables for them), so those notification types
-- don't exist here even though the UI has icons ready for them.
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,   -- recipient
  actor_id uuid not null,  -- who triggered it
  type text not null check (type in ('circle_memory', 'circle_join')),
  circle_id uuid references circles(id) on delete cascade,
  memory_id uuid references memories(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint notifications_user_id_fkey
    foreign key (user_id) references profiles(id) on delete cascade,
  constraint notifications_actor_id_fkey
    foreign key (actor_id) references profiles(id) on delete cascade
);

alter table notifications enable row level security;

create policy "users can view their own notifications"
  on notifications for select
  to authenticated
  using (user_id = auth.uid());

create policy "users can mark their own notifications read"
  on notifications for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Deliberately no insert policy for `authenticated` — notifications are
-- only ever created by the security-definer trigger functions below,
-- which bypass RLS. This stops a client from inserting fake notifications
-- into someone else's feed.

create or replace function notify_on_new_memory()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into notifications (user_id, actor_id, type, circle_id, memory_id)
  select cm.user_id, new.uploaded_by, 'circle_memory', new.circle_id, new.id
  from circle_members cm
  where cm.circle_id = new.circle_id
    and cm.user_id != new.uploaded_by;
  return new;
end;
$$;

drop trigger if exists on_memory_created on memories;
create trigger on_memory_created
  after insert on memories
  for each row execute function notify_on_new_memory();

create or replace function notify_on_circle_join()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into notifications (user_id, actor_id, type, circle_id)
  select cm.user_id, new.user_id, 'circle_join', new.circle_id
  from circle_members cm
  where cm.circle_id = new.circle_id
    and cm.user_id != new.user_id;
  return new;
end;
$$;

drop trigger if exists on_circle_member_added on circle_members;
create trigger on_circle_member_added
  after insert on circle_members
  for each row execute function notify_on_circle_join();

-- ─── reactions & comments ───────────────────────────────────────────────
-- One reaction per user per memory (tap again to remove/change) — kept
-- simple deliberately. Both tables reuse is_circle_member() via a join to
-- the parent memory, same privacy guarantee as everything else: only
-- people in that memory's circle can see or add to it.

create table if not exists memory_reactions (
  memory_id uuid not null references memories(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  primary key (memory_id, user_id)
);

alter table memory_reactions enable row level security;

create policy "circle members can view reactions"
  on memory_reactions for select
  to authenticated
  using (
    exists (
      select 1 from memories m
      where m.id = memory_id and is_circle_member(m.circle_id)
    )
  );

create policy "circle members can react"
  on memory_reactions for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from memories m
      where m.id = memory_id and is_circle_member(m.circle_id)
    )
  );

create policy "users can change their own reaction"
  on memory_reactions for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "users can remove their own reaction"
  on memory_reactions for delete
  to authenticated
  using (user_id = auth.uid());

create table if not exists memory_comments (
  id uuid primary key default gen_random_uuid(),
  memory_id uuid not null references memories(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

alter table memory_comments enable row level security;

create policy "circle members can view comments"
  on memory_comments for select
  to authenticated
  using (
    exists (
      select 1 from memories m
      where m.id = memory_id and is_circle_member(m.circle_id)
    )
  );

create policy "circle members can comment"
  on memory_comments for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from memories m
      where m.id = memory_id and is_circle_member(m.circle_id)
    )
  );

create policy "users can delete their own comment"
  on memory_comments for delete
  to authenticated
  using (user_id = auth.uid());

-- Notify only the memory's owner when someone else comments on it — not
-- the whole circle. (Reactions deliberately don't notify at all: much
-- lower signal, and would get noisy fast without a batching mechanism
-- we don't have yet.)
alter table notifications
  drop constraint if exists notifications_type_check;
alter table notifications
  add constraint notifications_type_check
  check (type in ('circle_memory', 'circle_join', 'memory_comment'));

create or replace function notify_on_new_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid;
begin
  select uploaded_by into owner_id from memories where id = new.memory_id;
  if owner_id is not null and owner_id != new.user_id then
    insert into notifications (user_id, actor_id, type, circle_id, memory_id)
    select owner_id, new.user_id, 'memory_comment', m.circle_id, new.memory_id
    from memories m where m.id = new.memory_id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_comment_created on memory_comments;
create trigger on_comment_created
  after insert on memory_comments
  for each row execute function notify_on_new_comment();

-- ─── circle invites (real join-via-link flow) ────────────────────────────
-- The circle_members insert policy above only allows an existing admin
-- (or the creator, at creation time) to add a row — nobody can add
-- themselves. That's correct for direct adds, but it means a plain
-- "share this link" flow with no token has no real way to let the
-- recipient join. This table + RPC close that gap properly: a token
-- proves someone was actually given the link by a real member, and the
-- RPC (running as security definer) is the only path that's allowed to
-- add a member on their own behalf, and only when redeeming a valid,
-- unrevoked, unexpired token for that specific circle.

create table if not exists circle_invites (
  token uuid primary key default gen_random_uuid(),
  circle_id uuid not null references circles(id) on delete cascade,
  created_by uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz, -- null = never expires (kept simple for V1)
  revoked boolean not null default false
);

alter table circle_invites enable row level security;

create policy "circle members can view their circle's invites"
  on circle_invites for select
  to authenticated
  using (is_circle_member(circle_id));

create policy "circle members can create invites for their circle"
  on circle_invites for insert
  to authenticated
  with check (is_circle_member(circle_id) and created_by = auth.uid());

create policy "circle members can revoke their circle's invites"
  on circle_invites for update
  to authenticated
  using (is_circle_member(circle_id))
  with check (is_circle_member(circle_id));

create or replace function redeem_circle_invite(invite_token uuid)
returns uuid -- the circle_id joined, on success
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_revoked boolean;
  v_expires_at timestamptz;
begin
  select circle_id, revoked, expires_at
    into v_circle_id, v_revoked, v_expires_at
  from circle_invites
  where token = invite_token;

  if v_circle_id is null then
    raise exception 'This invite link isn''t valid.';
  end if;

  if v_revoked then
    raise exception 'This invite link has been turned off.';
  end if;

  if v_expires_at is not null and v_expires_at < now() then
    raise exception 'This invite link has expired.';
  end if;

  insert into circle_members (circle_id, user_id, role)
  values (v_circle_id, auth.uid(), 'member')
  on conflict (circle_id, user_id) do nothing;

  return v_circle_id;
end;
$$;

-- Explicit, not implicit: only signed-in users can call this, nobody
-- anonymous.
revoke all on function redeem_circle_invite(uuid) from public;
grant execute on function redeem_circle_invite(uuid) to authenticated;
