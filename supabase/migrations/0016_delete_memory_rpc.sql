-- Delete a memory atomically as its owner.
-- SECURITY DEFINER avoids client-side RLS visibility/cascade ordering problems.
-- The function returns the deleted memory id so the app can only update its
-- local state after the database confirms the row was actually removed.

create or replace function public.delete_memory(p_memory_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_id uuid;
begin
  delete from public.memories
  where id = p_memory_id
    and uploaded_by = auth.uid()
  returning id into deleted_id;

  if deleted_id is null then
    raise exception 'Memory not found or you do not own it';
  end if;

  return deleted_id;
end;
$$;

revoke all on function public.delete_memory(uuid) from public;
grant execute on function public.delete_memory(uuid) to authenticated;

notify pgrst, 'reload schema';
