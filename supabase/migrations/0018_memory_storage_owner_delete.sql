-- Memory objects are stored at {memory_id}/{filename}.
-- Deleting the database row first is intentional: storage ownership is held
-- by Storage itself, not by the public.memories row. Use owner_id so the
-- object's owner can remove the asset even after the memory row is gone.

drop policy if exists "uploader can delete their own memory photo" on storage.objects;
drop policy if exists "memory owners can delete their own storage objects" on storage.objects;

create policy "memory owners can delete their own storage objects"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'memories'
  and owner_id = (select auth.uid()::text)
);

notify pgrst, 'reload schema';
