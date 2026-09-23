-- Harden memory deletion so it cannot be blocked by client-side RLS
-- visibility/cascade ordering. The function deletes only the authenticated
-- user's own memory and returns its id only after the row is gone.

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
