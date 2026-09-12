-- Fix the remaining memory_circles INSERT RLS failure.
-- The previous policy queried public.memories directly. Because memories has
-- its own SELECT RLS, a newly-created private memory can be invisible before
-- its first memory_circles row exists. Use the existing SECURITY DEFINER
-- ownership helper instead.

create or replace function public.user_is_circle_member_for_memory(
  circle_id_input uuid
)
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

grant execute
on function public.user_is_circle_member_for_memory(uuid)
to authenticated;

-- Remove only INSERT policies on memory_circles. Keep SELECT and other
-- policies unchanged.
do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'memory_circles'
      and cmd = 'INSERT'
  loop
    execute format(
      'drop policy if exists %I on public.memory_circles',
      policy_record.policyname
    );
  end loop;
end
$$;

create policy "memory uploader can share to member circles"
on public.memory_circles
for insert
to authenticated
with check (
  public.user_is_circle_member_for_memory(circle_id)
  and public.is_memory_uploader(memory_id)
);

notify pgrst, 'reload schema';
