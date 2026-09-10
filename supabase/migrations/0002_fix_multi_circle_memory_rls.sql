-- Fix live multi-circle/public memory RLS.
-- This is the database migration required by the existing Create Memory code.
-- Safe to run more than once in Supabase SQL Editor.

-- 1. Multi-circle schema
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

-- 2. One visibility function for memories + storage
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
          where mc.memory_id = m.id
            and is_circle_member(mc.circle_id)
        )
      )
  );
$$;

grant execute on function can_view_memory(uuid) to authenticated;

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

grant execute on function is_memory_uploader(uuid) to authenticated;

-- 3. Memory RLS

drop policy if exists "members can view memories in their circles" on memories;
drop policy if exists "users can view memories they can access" on memories;
create policy "users can view memories they can access"
  on memories for select
  to authenticated
  using (can_view_memory(id));

drop policy if exists "members can add memories to their circles" on memories;
drop policy if exists "users can add their own memories" on memories;
create policy "users can add their own memories"
  on memories for insert
  to authenticated
  with check (uploaded_by = auth.uid());

-- 4. Memory storage RLS
-- Files are stored at {memoryId}/{filename}; uploader ownership controls upload,
-- and can_view_memory controls reads for public or circle-shared memories.
drop policy if exists "circle members can upload to their circle's folder" on storage.objects;
drop policy if exists "uploader can upload to their own memory's folder" on storage.objects;
create policy "uploader can upload to their own memory's folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'memories'
    and is_memory_uploader((storage.foldername(name))[1]::uuid)
  );

drop policy if exists "circle members can read their circle's photos" on storage.objects;
drop policy if exists "memory photo is visible to whoever can view its row" on storage.objects;
create policy "memory photo is visible to whoever can view its row"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'memories'
    and can_view_memory((storage.foldername(name))[1]::uuid)
  );

-- 5. Notifications: notify per circle share, not per memory row.
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

notify pgrst, 'reload schema';
