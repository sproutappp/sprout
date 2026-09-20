-- Allow a signed-in user to add an accessible memory to a circle they belong to.
-- This is an additional share; it does not change the memory's public/private flag.
drop policy if exists "members can add accessible memories to their circles" on public.memory_circles;
create policy "members can add accessible memories to their circles"
  on public.memory_circles
  for insert
  to authenticated
  with check (
    public.user_is_circle_member_for_memory(circle_id)
    and public.can_view_memory(memory_id)
  );

drop policy if exists "members can update accessible memory circle shares" on public.memory_circles;
create policy "members can update accessible memory circle shares"
  on public.memory_circles
  for update
  to authenticated
  using (
    public.user_is_circle_member_for_memory(circle_id)
    and public.can_view_memory(memory_id)
  )
  with check (
    public.user_is_circle_member_for_memory(circle_id)
    and public.can_view_memory(memory_id)
  );

notify pgrst, 'reload schema';
