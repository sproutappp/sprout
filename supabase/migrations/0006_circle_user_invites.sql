-- In-app circle invitations to existing Sprout users.
alter table circle_invites
  add column if not exists invited_user_id uuid references profiles(id) on delete cascade;

alter table notifications
  add column if not exists invite_token uuid references circle_invites(token) on delete cascade;

alter table notifications
  drop constraint if exists notifications_type_check;
alter table notifications
  add constraint notifications_type_check
  check (type in ('circle_memory', 'circle_join', 'memory_comment', 'circle_invite'));

create or replace function send_circle_invites(p_circle_id uuid, p_user_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_token uuid;
  v_count integer := 0;
  v_is_admin boolean;
begin
  select exists (
    select 1 from circle_members
    where circle_id = p_circle_id
      and user_id = auth.uid()
      and role = 'admin'
  ) into v_is_admin;

  if not v_is_admin then
    raise exception 'Only circle admins can send invitations.';
  end if;

  foreach v_user_id in array p_user_ids loop
    if v_user_id is null or v_user_id = auth.uid() then
      continue;
    end if;

    if exists (
      select 1 from circle_members
      where circle_id = p_circle_id and user_id = v_user_id
    ) then
      continue;
    end if;

    v_token := gen_random_uuid();
    insert into circle_invites (token, circle_id, created_by, invited_user_id)
    values (v_token, p_circle_id, auth.uid(), v_user_id);

    insert into notifications (user_id, actor_id, type, circle_id, invite_token)
    values (v_user_id, auth.uid(), 'circle_invite', p_circle_id, v_token);

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function send_circle_invites(uuid, uuid[]) from public;
grant execute on function send_circle_invites(uuid, uuid[]) to authenticated;

notify pgrst, 'reload schema';
