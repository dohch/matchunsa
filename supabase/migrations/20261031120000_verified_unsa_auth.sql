-- Reuse this helper in every RLS policy for data that requires a verified UNSA account.
-- It checks the trusted auth.users record instead of user-editable metadata.
create or replace function public.is_verified_unsa_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from auth.users
    where id = (select auth.uid())
      and email_confirmed_at is not null
      and lower(email) ~ '^[^@]+@unsa[.]edu[.]pe$'
  );
$$;

revoke all on function public.is_verified_unsa_user() from public;
grant execute on function public.is_verified_unsa_user() to authenticated;
