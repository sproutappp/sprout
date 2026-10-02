create or replace function public.merge_sprout_accounts(
  source_user_id uuid,
  target_user_id uuid
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  source_mobile text;
  target_mobile text;
  moved_circle_members integer := 0;
  moved_reactions integer := 0;
  moved_people integer := 0;
  moved_circles integer := 0;
  moved_memories integer := 0;
  moved_comments integer := 0;
  moved_notifications integer := 0;
  moved_invites integer := 0;
  moved_storage integer := 0;
begin
  if source_user_id is null or target_user_id is null or source_user_id = target_user_id then
    raise exception 'Source and target accounts must be different';
  end if;

  perform 1 from public.profiles where id = source_user_id for update;
  if not found then raise exception 'Source profile not found'; end if;
  perform 1 from public.profiles where id = target_user_id for update;
  if not found then raise exception 'Target profile not found'; end if;

  select mobile_number into source_mobile
  from public.private_profile_info
  where id = source_user_id
  for update;

  select mobile_number into target_mobile
  from public.private_profile_info
  where id = target_user_id
  for update;

  if source_mobile is not null and target_mobile is not null and source_mobile <> target_mobile then
    raise exception 'Target account already has a different mobile number';
  end if;

  update storage.objects
  set owner = target_user_id,
      owner_id = target_user_id::text
  where owner = source_user_id;
  get diagnostics moved_storage = row_count;

  update public.circles set created_by = target_user_id where created_by = source_user_id;
  get diagnostics moved_circles = row_count;

  update public.memories set uploaded_by = target_user_id where uploaded_by = source_user_id;
  get diagnostics moved_memories = row_count;

  update public.memory_comments set user_id = target_user_id where user_id = source_user_id;
  get diagnostics moved_comments = row_count;

  update public.notifications set user_id = target_user_id where user_id = source_user_id;
  get diagnostics moved_notifications = row_count;

  update public.notifications set actor_id = target_user_id where actor_id = source_user_id;

  update public.circle_invites set created_by = target_user_id where created_by = source_user_id;
  update public.circle_invites set invited_user_id = target_user_id where invited_user_id = source_user_id;
  get diagnostics moved_invites = row_count;

  insert into public.circle_members (circle_id, user_id, role, joined_at)
  select circle_id, target_user_id, role, joined_at
  from public.circle_members
  where user_id = source_user_id
  on conflict (circle_id, user_id) do update
    set role = case
      when public.circle_members.role = 'admin' or excluded.role = 'admin'
        then 'admin'
      else 'member'
    end,
    joined_at = least(public.circle_members.joined_at, excluded.joined_at);

  delete from public.circle_members where user_id = source_user_id;
  get diagnostics moved_circle_members = row_count;

  insert into public.memory_reactions (memory_id, user_id, emoji, created_at)
  select memory_id, target_user_id, emoji, created_at
  from public.memory_reactions
  where user_id = source_user_id
  on conflict (memory_id, user_id) do nothing;

  delete from public.memory_reactions where user_id = source_user_id;
  get diagnostics moved_reactions = row_count;

  insert into public.memory_people (memory_id, person_id, created_at)
  select memory_id, target_user_id, created_at
  from public.memory_people
  where person_id = source_user_id
  on conflict (memory_id, person_id) do nothing;

  delete from public.memory_people where person_id = source_user_id;
  get diagnostics moved_people = row_count;

  if source_mobile is not null then
    insert into public.private_profile_info (id, mobile_number)
    values (target_user_id, source_mobile)
    on conflict (id) do update
      set mobile_number = excluded.mobile_number;
  end if;
  delete from public.private_profile_info where id = source_user_id;

  update public.profiles target
  set full_name = coalesce(nullif(source.full_name, ''), target.full_name),
      date_of_birth = coalesce(source.date_of_birth, target.date_of_birth),
      avatar_url = coalesce(source.avatar_url, target.avatar_url)
  from public.profiles source
  where target.id = target_user_id
    and source.id = source_user_id;

  delete from public.profiles where id = source_user_id;

  return jsonb_build_object(
    'source_user_id', source_user_id,
    'target_user_id', target_user_id,
    'moved_circles', moved_circles,
    'moved_memories', moved_memories,
    'moved_circle_members', moved_circle_members,
    'moved_reactions', moved_reactions,
    'moved_memory_people', moved_people,
    'moved_comments', moved_comments,
    'moved_notifications', moved_notifications,
    'moved_invites', moved_invites,
    'moved_storage', moved_storage
  );
end;
$$;

revoke execute on function public.merge_sprout_accounts(uuid, uuid) from public, anon, authenticated;
grant execute on function public.merge_sprout_accounts(uuid, uuid) to service_role;
