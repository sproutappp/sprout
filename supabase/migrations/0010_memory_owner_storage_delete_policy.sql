-- Allow the owner of a memory to remove its private storage object.
-- Memory files are stored at {memory_id}/{filename}, so ownership can be
-- checked through the existing is_memory_uploader() security-definer helper.

drop policy if exists "uploader can delete their own memory photo" on storage.objects;
create policy "uploader can delete their own memory photo"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'memories'
    and is_memory_uploader((storage.foldername(name))[1]::uuid)
  );

notify pgrst, 'reload schema';
