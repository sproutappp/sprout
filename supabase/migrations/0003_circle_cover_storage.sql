-- Circle covers live in their own public Storage bucket.
-- Public is intentional: cover images are presentation assets, not private memories.

insert into storage.buckets (id, name, public)
values ('circle-covers', 'circle-covers', true)
on conflict (id) do update set public = true;

drop policy if exists "users can upload their circle covers" on storage.objects;
create policy "users can upload their circle covers"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'circle-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "users can delete their circle covers" on storage.objects;
create policy "users can delete their circle covers"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'circle-covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allows the creator to roll back a just-created circle if cover/member
-- setup fails after the storage upload.
drop policy if exists "creators can delete their own circles" on circles;
create policy "creators can delete their own circles"
  on circles for delete
  to authenticated
  using (created_by = auth.uid());

notify pgrst, 'reload schema';
