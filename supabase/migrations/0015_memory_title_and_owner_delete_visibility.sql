-- Keep title and caption as separate fields so list cards never have to
-- reconstruct one from the other.
alter table public.memories
  add column if not exists title text;

-- Migrate legacy rows that stored "title — caption" in caption.
update public.memories
set
  title = case
    when position(' — ' in coalesce(caption, '')) > 0
      then btrim(split_part(caption, ' — ', 1))
    else nullif(btrim(caption), '')
  end,
  caption = case
    when position(' — ' in coalesce(caption, '')) > 0
      then nullif(btrim(substr(caption, position(' — ' in caption) + 3)), '')
    else null
  end
where title is null;

-- PostgREST applies SELECT visibility as part of filtered DELETEs. Give the
-- uploader an explicit SELECT path independent of circle membership so an
-- orphaned or partially-shared memory can always be removed by its owner.
drop policy if exists "memory owners can view their own memories" on public.memories;
create policy "memory owners can view their own memories"
  on public.memories for select
  to authenticated
  using (uploaded_by = auth.uid());

create index if not exists memories_uploaded_by_idx on public.memories(uploaded_by);

notify pgrst, 'reload schema';
