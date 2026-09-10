-- Sprout: memory & circles schema
-- Run this once in Supabase Dashboard > SQL Editor on a fresh project.

-- ─── profiles ────────────────────────────────────────────────────────────
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now()
);

-- Added for the Edit Profile "Date of Birth" field. `if not exists` makes
-- this safe to run again on a project that already has the base table
-- above (this is the one statement in this file you need to run by hand
-- against an existing/live project — everything else was already applied).
alter table profiles add column if not exists date_of_birth date;

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

-- ─── avatars storage ───────────────────────────────────────────────────
-- Public bucket — profile pictures are low-sensitivity compared to
-- family memory photos, and profiles.avatar_url is already readable by
-- any signed-in user via the profiles table's own RLS policy, so a
-- public bucket doesn't expose anything that wasn't already visible.
-- This also avoids needing to refresh signed URLs for something this
-- simple (unlike the private `memories` bucket).

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

create policy "anyone signed in can view avatars"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'avatars');

create policy "users can upload their own avatar"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "users can replace their own avatar"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ═══════════════════════════════════════════════════════════════════════
-- MIGRATION — run this whole block by hand in the Supabase SQL editor
-- against the live project. Everything above this line was already
-- applied; everything below is new as of this change and has NOT been
-- run against the live database yet. Safe to run more than once
-- (idempotent: uses if-exists/if-not-exists/or-replace throughout).
-- ═══════════════════════════════════════════════════════════════════════

-- ─── 1. Fix circle creation (RLS deadlock) ─────────────────────────────
-- Root cause of "Can't create the circle": CirclesRepository.createCircle
-- does `insert into circles ... .select().single()` — PostgREST applies
-- the SELECT policy to the INSERT's RETURNING clause. The old SELECT
-- policy only allowed rows where is_circle_member(id) is true, i.e. a
-- circle_members row already exists for that circle — but at the moment
-- of creating the circle, the creator's circle_members row doesn't exist
-- yet (that's a separate second insert). So the RETURNING select saw zero
-- rows and `.single()` threw. Letting the creator see their own circle
-- unconditionally (not just members) closes that gap without weakening
-- anything for anyone else — only the actual creator (created_by =
-- auth.uid()) gets this extra visibility.
drop policy if exists "members can view their circles" on circles;
create policy "members can view their circles"
  on circles for select
  to authenticated
  using (is_circle_member(id) or created_by = auth.uid());

-- ─── 2. Identity linking: verified mobile number, kept private ────────
-- IMPORTANT: this is NOT a column on `profiles`. The existing "profiles
-- are readable by any signed-in user" policy applies to the whole row,
-- so a mobile_number column there would leak everyone's phone number to
-- every other signed-in user. It lives in its own table instead, with
-- its own owner-only RLS, and a security-definer function
-- (is_mobile_number_taken) is the only way to check "is this number
-- already linked" without exposing whose it is.
create table if not exists private_profile_info (
  id uuid primary key references profiles(id) on delete cascade,
  mobile_number text
);

alter table private_profile_info enable row level security;

drop policy if exists "users can view their own private info" on private_profile_info;
create policy "users can view their own private info"
  on private_profile_info for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "users can create their own private info" on private_profile_info;
create policy "users can create their own private info"
  on private_profile_info for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "users can update their own private info" on private_profile_info;
create policy "users can update their own private info"
  on private_profile_info for update
  to authenticated
  using (auth.uid() = id);

drop index if exists private_profile_info_mobile_unique_idx;
create unique index private_profile_info_mobile_unique_idx
  on private_profile_info (mobile_number)
  where mobile_number is not null;

-- Lets the client check "is this number already linked to *someone*"
-- (to give a clear message before even trying Firebase verification)
-- without ever exposing whose account it belongs to.
create or replace function is_mobile_number_taken(phone text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from private_profile_info where mobile_number = phone
  );
$$;

-- ─── 3. Multi-circle + public memories ─────────────────────────────────
-- memories.circle_id becomes nullable: a memory is either public
-- (is_public = true, no circles) or shared to one-or-more circles via
-- the new memory_circles join table below. circle_id itself is kept
-- (as the "primary"/first-selected circle) purely so existing screens
-- that show one circle badge per memory keep working unchanged — the
-- join table, not this column, is the source of truth for who can
-- actually see the memory.
alter table memories alter column circle_id drop not null;
alter table memories add column if not exists is_public boolean not null default false;

create table if not exists memory_circles (
  memory_id uuid not null references memories(id) on delete cascade,
  circle_id uuid not null references circles(id) on delete cascade,
  primary key (memory_id, circle_id)
);

alter table memory_circles enable row level security;

drop policy if exists "circle members can view their circle's memory shares" on memory_circles;
create policy "circle members can view their circle's memory shares"
  on memory_circles for select
  to authenticated
  using (is_circle_member(circle_id));

drop policy if exists "uploader can share their own memory to their circles" on memory_circles;
create policy "uploader can share their own memory to their circles"
  on memory_circles for insert
  to authenticated
  with check (
    is_circle_member(circle_id)
    and exists (
      select 1 from memories m
      where m.id = memory_id and m.uploaded_by = auth.uid()
    )
  );

-- Single source of truth for "can the current user see this memory" —
-- reused below by both the memories table policy and the storage policy,
-- so there's exactly one place that defines memory visibility.
create or replace function can_view_memory(mem_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from memories m
    where m.id = mem_id
      and (
        m.is_public
        or exists (
          select 1 from memory_circles mc
          where mc.memory_id = m.id and is_circle_member(mc.circle_id)
        )
      )
  );
$$;

drop policy if exists "members can view memories in their circles" on memories;
create policy "memories are visible per can_view_memory"
  on memories for select
  to authenticated
  using (can_view_memory(id));

-- ─── 3b. Fix reactions/comments for public + multi-circle memories ─────
-- The original reactions/comments policies above (section "reactions &
-- comments") still check is_circle_member(m.circle_id) directly — that
-- predates public memories (circle_id is now nullable, so this is null
-- for a public memory and the check always fails) and multi-circle
-- sharing (it only ever looked at the single circle_id column, so
-- members of a *secondary* shared circle could see a memory via
-- can_view_memory() but still couldn't react/comment on it). Replace
-- both with can_view_memory(memory_id), which already accounts for
-- public visibility and every circle a memory is shared to.
drop policy if exists "circle members can view reactions" on memory_reactions;
create policy "anyone who can view the memory can view reactions"
  on memory_reactions for select
  to authenticated
  using (can_view_memory(memory_id));

drop policy if exists "circle members can react" on memory_reactions;
create policy "anyone who can view the memory can react"
  on memory_reactions for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and can_view_memory(memory_id)
  );
-- "users can change/remove their own reaction" (update/delete) already
-- key off user_id = auth.uid() only and need no change.

drop policy if exists "circle members can view comments" on memory_comments;
create policy "anyone who can view the memory can view comments"
  on memory_comments for select
  to authenticated
  using (can_view_memory(memory_id));

drop policy if exists "circle members can comment" on memory_comments;
create policy "anyone who can view the memory can comment"
  on memory_comments for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and can_view_memory(memory_id)
  );
-- "users can delete their own comment" already keys off user_id =
-- auth.uid() only and needs no change.

-- Circle-membership checks for each shared circle are enforced by the
-- memory_circles insert policy above (a separate statement); this only
-- needs to confirm people can't insert memory rows claiming to be
-- someone else's upload. Public memories need no circle check at all.
drop policy if exists "members can add memories to their circles" on memories;
create policy "users can add their own memories"
  on memories for insert
  to authenticated
  with check (uploaded_by = auth.uid());

-- ─── 4. Storage: same can_view_memory check, keyed by path ─────────────
-- The app now uploads to `{memory_id}/{filename}` (was `{circle_id}/...`)
-- so a single per-memory check works for storage the same way it works
-- for the memories table — see MemoriesRepository.addMemory for the
-- matching Dart-side change (insert the memories row first, then upload
-- to the id-keyed path, so this insert policy's existence check passes).
drop policy if exists "circle members can read their circle's photos" on storage.objects;
create policy "memory photo is visible to whoever can view its row"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'memories'
    and can_view_memory((storage.foldername(name))[1]::uuid)
  );

-- Dedicated check for "is the current user this memory's uploader" — kept
-- separate from can_view_memory (which is about *visibility*, e.g. any
-- circle member or anyone if public) and marked security definer so it
-- doesn't depend on the memories row already being visible under RLS at
-- the moment it's checked. Used by the storage insert policy below.
create or replace function is_memory_uploader(mem_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from memories m
    where m.id = mem_id and m.uploaded_by = auth.uid()
  );
$$;

drop policy if exists "circle members can upload to their circle's folder" on storage.objects;
create policy "uploader can upload to their own memory's folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'memories'
    and is_memory_uploader((storage.foldername(name))[1]::uuid)
  );

-- ─── 5. Notifications: fan out per circle share, not per memory ───────
-- The old trigger fired once on `memories` insert, keyed off the single
-- circle_id column. With sharing now possibly spanning several circles
-- via memory_circles (inserted in a separate statement right after the
-- memories row), notification fan-out moves to fire per memory_circles
-- row instead — once per circle actually shared to, whether that's one
-- circle or several. Public memories intentionally produce no
-- "new memory in your circle" notifications (nobody's circle received
-- anything in that case).
drop trigger if exists on_memory_created on memories;
drop function if exists notify_on_new_memory();

create or replace function notify_on_memory_shared_to_circle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into notifications (user_id, actor_id, type, circle_id, memory_id)
  select cm.user_id, m.uploaded_by, 'circle_memory', new.circle_id, new.memory_id
  from circle_members cm
  join memories m on m.id = new.memory_id
  where cm.circle_id = new.circle_id
    and cm.user_id != m.uploaded_by;
  return new;
end;
$$;

drop trigger if exists on_memory_shared_to_circle on memory_circles;
create trigger on_memory_shared_to_circle
  after insert on memory_circles
  for each row execute function notify_on_memory_shared_to_circle();
