-- Fix circle-memory creation when circle_members RLS blocks the membership check.
-- This is intentionally limited to the memory_circles INSERT policy.

create or replace function public.user_is_circle_member_for_memory(circle_id_input uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.circle_members cm
    where cm.circle_id = circle_id_input
      and cm.user_id = auth.uid()
  );
$$;

grant execute on function public.user_is_circle_member_for_memory(uuid) to authenticated;

drop policy if exists "uploader can share their own memory to their circles" on public.memory_circles;

create policy "uploader can share their own memory to their circles"
  on public.memory_circles
  for insert
  to authenticated
  with check (
    public.user_is_circle_member_for_memory(circle_id)
    and exists (
      select 1
      from public.memories m
      where m.id = memory_id
        and m.uploaded_by = auth.uid()
    )
  );

notify pgrst, 'reload schema';
