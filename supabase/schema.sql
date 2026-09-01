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
-- Create the bucket first (Dashboard > Storage > New bucket, name: "memories",
-- Public: ON — we serve images via public URL and gate access at upload time
-- via RLS below; switch to signed URLs later if you want private-by-default).

insert into storage.buckets (id, name, public)
values ('memories', 'memories', true)
on conflict (id) do nothing;

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
