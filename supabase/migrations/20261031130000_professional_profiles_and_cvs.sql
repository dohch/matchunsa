create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  first_names text not null check (length(btrim(first_names)) > 0),
  last_names text not null check (length(btrim(last_names)) > 0),
  phone text,
  linkedin_url text,
  career text not null check (length(btrim(career)) > 0),
  academic_status text not null
    check (academic_status in ('student', 'graduate', 'bachelor')),
  semester integer check (semester is null or semester > 0),
  skills text[] not null default '{}',
  cv_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
revoke all on table public.profiles from anon, authenticated;
grant select, insert, update on table public.profiles to authenticated;

create policy "Verified UNSA users can read their own profile"
on public.profiles for select to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can create their own profile"
on public.profiles for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can update their own profile"
on public.profiles for update to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
)
with check (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create or replace function public.set_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_profile_updated_at();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('professional-cvs', 'professional-cvs', false, 10485760, array['application/pdf'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "Verified UNSA users can read their own CV"
on storage.objects for select to authenticated
using (
  bucket_id = 'professional-cvs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can upload their own CV"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'professional-cvs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can replace their own CV"
on storage.objects for update to authenticated
using (
  bucket_id = 'professional-cvs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (select public.is_verified_unsa_user())
)
with check (
  bucket_id = 'professional-cvs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can delete their own CV"
on storage.objects for delete to authenticated
using (
  bucket_id = 'professional-cvs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and (select public.is_verified_unsa_user())
);
