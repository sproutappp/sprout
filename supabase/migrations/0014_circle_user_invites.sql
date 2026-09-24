-- Ensure the in-app invitation flow exists on databases that were created
-- before the original circle invite migration was applied.

alter table public.circle_invites
  add column if not exists invited_user_id uuid references public.profiles(id) on delete cascade;

alter table public.notifications
  add column if not exists invite_token uuid references public.circle_invites(token) on delete cascade;

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type in ('circle_memory', 'circle_join', 'memory_comment', 'circle_invite'));

create or replace function public.send_circle_invites(
  p_circle_id uuid,
  p_user_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_token uuid;
  v_count integer := 0;
begin
  if not exists (
    select 1
    from circle_members
    where circle_id = p_circle_id
      and user_id = auth.uid()
      and role = 'admin'
  ) then
    raise exception 'Only circle admins can send invitations.';
  end if;

  foreach v_user_id in array p_user_ids loop
    if v_user_id is null or v_user_id = auth.uid() then
      continue;
    end if;

    if exists (
      select 1
      from circle_members
      where circle_id = p_circle_id
        and user_id = v_user_id
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

revoke all on function public.send_circle_invites(uuid, uuid[]) from public;
grant execute on function public.send_circle_invites(uuid, uuid[]) to authenticated;

-- Only the intended recipient can redeem a user-targeted invite. Legacy
-- share links without invited_user_id continue to work as before.
create or replace function public.redeem_circle_invite(invite_token uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_circle_id uuid;
  v_invited_user_id uuid;
  v_revoked boolean;
  v_expires_at timestamptz;
begin
  select circle_id, invited_user_id, revoked, expires_at
    into v_circle_id, v_invited_user_id, v_revoked, v_expires_at
  from circle_invites
  where token = invite_token;

  if v_circle_id is null then
    raise exception 'This invite link isn''t valid.';
  end if;

  if v_revoked then
    raise exception 'This invite link has been turned off.';
  end if;

  if v_expires_at is not null and v_expires_at < now() then
    raise exception 'This invite link has expired.';
  end if;

  if v_invited_user_id is not null and v_invited_user_id <> auth.uid() then
    raise exception 'This invite was sent to a different Sprout user.';
  end if;

  insert into circle_members (circle_id, user_id, role)
  values (v_circle_id, auth.uid(), 'member')
  on conflict (circle_id, user_id) do nothing;

  return v_circle_id;
end;
$$;

revoke all on function public.redeem_circle_invite(uuid) from public;
grant execute on function public.redeem_circle_invite(uuid) to authenticated;

-- Notification taps already navigate to the circle detail route. This helper
-- lets that route accept a pending in-app invitation before the normal member
-- RLS query runs, without exposing invite rows to non-members.
create or replace function public.redeem_pending_circle_invite(p_circle_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token uuid;
begin
  if exists (
    select 1
    from circle_members
    where circle_id = p_circle_id
      and user_id = auth.uid()
  ) then
    return false;
  end if;

  select token
    into v_token
  from circle_invites
  where circle_id = p_circle_id
    and invited_user_id = auth.uid()
    and revoked = false
    and (expires_at is null or expires_at >= now())
  order by created_at desc
  limit 1;

  if v_token is null then
    return false;
  end if;

  perform public.redeem_circle_invite(v_token);
  return true;
end;
$$;

revoke all on function public.redeem_pending_circle_invite(uuid) from public;
grant execute on function public.redeem_pending_circle_invite(uuid) to authenticated;

notify pgrst, 'reload schema';

-- Allow a signed-in user to add or update an accessible memory in a circle they belong to.
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
