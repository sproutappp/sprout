-- Notifications are a side effect of sharing a memory to a circle.
-- A notification failure must never make the memory itself fail to save.
create or replace function notify_on_memory_shared_to_circle()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    insert into notifications (user_id, actor_id, type, circle_id, memory_id)
    select cm.user_id, m.uploaded_by, 'circle_memory', new.circle_id, new.memory_id
    from circle_members cm
    join memories m on m.id = new.memory_id
    where cm.circle_id = new.circle_id
      and cm.user_id != m.uploaded_by;
  exception when others then
    -- Notification delivery is best-effort; never abort the memory share.
    null;
  end;
  return new;
end;
$$;

grant execute on function notify_on_memory_shared_to_circle() to authenticated;
notify pgrst, 'reload schema';
