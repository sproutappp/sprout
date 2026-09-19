-- Memory editing, multi-circle audience management, and people tagging.
-- Safe to run once; every statement is idempotent where practical.

alter table memories add column if not exists location text;
alter table memories add column if not exists is_public boolean not null default false;

-- Owner can edit their own memory metadata.
drop policy if exists "owners can update their own memories" on memories;
create policy "owners can update their own memories"
  on memories for update
  to authenticated
  using (uploaded_by = auth.uid())
  with check (uploaded_by = auth.uid());

-- Owner can remove a circle share from a memory they own.
drop policy if exists "uploader can remove their own memory circle shares" on memory_circles;
create policy "uploader can remove their own memory circle shares"
  on memory_circles for delete
  to authenticated
  using (
    exists (
      select 1 from memories m
      where m.id = memory_id and m.uploaded_by = auth.uid()
    )
  );

-- People tagged in a memory. A person may be tagged once per memory.
create table if not exists memory_people (
  memory_id uuid not null references memories(id) on delete cascade,
  person_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (memory_id, person_id)
);

alter table memory_people enable row level security;

drop policy if exists "view people tags on accessible memories" on memory_people;
create policy "view people tags on accessible memories"
  on memory_people for select
  to authenticated
  using (can_view_memory(memory_id));

drop policy if exists "memory owner can add people tags" on memory_people;
create policy "memory owner can add people tags"
  on memory_people for insert
  to authenticated
  with check (
    exists (
      select 1 from memories m
      where m.id = memory_id and m.uploaded_by = auth.uid()
    )
    and exists (
      select 1
      from memory_circles mc
      join circle_members cm on cm.circle_id = mc.circle_id
      where mc.memory_id = memory_people.memory_id
        and cm.user_id = memory_people.person_id
    )
  );

drop policy if exists "memory owner can remove people tags" on memory_people;
create policy "memory owner can remove people tags"
  on memory_people for delete
  to authenticated
  using (
    exists (
      select 1 from memories m
      where m.id = memory_id and m.uploaded_by = auth.uid()
    )
  );

notify pgrst, 'reload schema';
