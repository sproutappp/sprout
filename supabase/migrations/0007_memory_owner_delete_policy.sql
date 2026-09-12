-- Allow a memory uploader to delete only their own memory rows.
-- Related memory_circles rows are removed by the existing FK cascade.
-- Storage cleanup is handled by the client before the row is deleted.

create policy "users can delete their own memories"
  on public.memories for delete
  to authenticated
  using (uploaded_by = auth.uid());

notify pgrst, 'reload schema';
