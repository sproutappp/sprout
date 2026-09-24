-- Circle deletion: owner-only hard delete, member notification, and persisted
-- notification text so the notification survives the circle's cascading delete.

alter table public.notifications
  add column if not exists message text;

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (
    type in (
      'circle_memory',
      'circle_join',
      'memory_comment',
      'circle_invite',
      'circle_deleted'
    )
  );

create or replace function public.leave_circle(p_circle_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'You must be signed in.';
  end if;

  delete from public.circle_members
  where circle_id = p_circle_id
    and user_id = (select auth.uid())
    and role = 'member'
  returning circle_id into deleted_id;

  if deleted_id is null then
    if exists (
      select 1
      from public.circle_members
      where circle_id = p_circle_id
        and user_id = (select auth.uid())
        and role = 'admin'
    ) then
      raise exception 'Circle admins cannot leave their circle. Delete the circle instead.';
    end if;

    raise exception 'Circle membership not found.';
  end if;

  return true;
end;
$$;

revoke all on function public.leave_circle(uuid) from public;
grant execute on function public.leave_circle(uuid) to authenticated;

-- The database delete itself is protected by creator ownership. The app calls
-- this function instead of relying on a client DELETE, because PostgREST
-- DELETE can affect zero visible rows under RLS without giving the UI a
-- positive deletion confirmation.
create or replace function public.delete_circle(p_circle_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_circle_name text;
  v_created_by uuid;
  v_member_id uuid;
  v_deleted_id uuid;
begin
  v_user_id := (select auth.uid());

  if v_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  select c.name, c.created_by
    into v_circle_name, v_created_by
  from public.circles c
  where c.id = p_circle_id;

  if v_circle_name is null then
    raise exception 'Circle not found.';
  end if;

  if v_created_by <> v_user_id then
    raise exception 'Only the circle creator can delete this circle.';
  end if;

  if not exists (
    select 1
    from public.circle_members cm
    where cm.circle_id = p_circle_id
      and cm.user_id = v_user_id
      and cm.role = 'admin'
  ) then
    raise exception 'Only the circle admin can delete this circle.';
  end if;

  -- Save the human-readable message before the circle is deleted. The
  -- circle_id is intentionally NULL because the circle row is about to be
  -- removed and the notification must survive that cascade.
  for v_member_id in
    select cm.user_id
    from public.circle_members cm
    where cm.circle_id = p_circle_id
      and cm.user_id <> v_user_id
  loop
    insert into public.notifications
      (user_id, actor_id, type, circle_id, memory_id, message, is_read)
    values
      (
        v_member_id,
        v_user_id,
        'circle_deleted',
        null,
        null,
        (select coalesce(p.full_name, 'Someone')
         from public.profiles p
         where p.id = v_user_id)
        || ' has deleted the ' || v_circle_name,
        false
      );
  end loop;

  delete from public.circles
  where id = p_circle_id
    and created_by = v_user_id
  returning id into v_deleted_id;

  if v_deleted_id is null then
    raise exception 'Circle deletion was not completed.';
  end if;

  return true;
end;
$$;

revoke all on function public.delete_circle(uuid) from public;
grant execute on function public.delete_circle(uuid) to authenticated;

notify pgrst, 'reload schema';
