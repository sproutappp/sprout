-- Allow a memory owner to remove the storage object belonging to their memory.
-- Files are stored at {memory_id}/{filename}, so ownership is checked
-- against the live public.memories row before the row is deleted.

drop policy if exists "uploader can delete their own memory photo" on storage.objects;
create policy "uploader can delete their own memory photo"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'memories'
    and exists (
      select 1
      from public.memories m
      where m.id::text = (storage.foldername(name))[1]
        and m.uploaded_by = auth.uid()
    )
  );

notify pgrst, 'reload schema';
