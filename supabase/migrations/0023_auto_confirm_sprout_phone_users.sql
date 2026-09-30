-- Phone-auth bridge accounts use a non-user-facing synthetic email.
-- Confirm only that internal domain so Supabase password sign-in works
-- without changing confirmation requirements for normal email accounts.

create or replace function public.confirm_sprout_phone_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if new.email like 'phone+%@sproutapp.in' then
    update auth.users
       set email_confirmed_at = coalesce(email_confirmed_at, now())
     where id = new.id
       and email_confirmed_at is null;
  end if;
  return new;
end;
$$;

drop trigger if exists on_sprout_phone_user_created on auth.users;

create trigger on_sprout_phone_user_created
after insert on auth.users
for each row
execute function public.confirm_sprout_phone_user();

-- Repair the phone accounts created before this fix.
update auth.users
   set email_confirmed_at = coalesce(email_confirmed_at, now())
 where email like 'phone+%@sproutapp.in'
   and email_confirmed_at is null;
