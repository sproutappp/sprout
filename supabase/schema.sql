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
