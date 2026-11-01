-- Migration: Complete MatchUNSA features
-- Modules: Favorites, Job Applications Tracking, Notifications, Admin Panel & Reports, Profile Extensions

-- 1. Profile Extensions (Module F)
alter table public.profiles
  add column if not exists faculty text,
  add column if not exists student_code text,
  add column if not exists additional_info text;

comment on column public.profiles.faculty is 'Facultad a la que pertenece el estudiante o egresado.';
comment on column public.profiles.student_code is 'Código universitario oficial UNSA.';
comment on column public.profiles.additional_info is 'Información profesional adicional, objetivos o resumen de experiencia.';

-- 2. Opportunities Active Flag and Admin Roles (Module E)
alter table public.opportunities
  add column if not exists is_active boolean not null default true;

comment on column public.opportunities.is_active is 'Indica si la convocatoria está activa o fue archivada/desactivada por moderación.';

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique check (length(btrim(email)) > 0),
  created_at timestamptz not null default now()
);

alter table public.app_admins enable row level security;
revoke all on table public.app_admins from anon, authenticated;
grant select on table public.app_admins to authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_admins
    where user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create policy "Authenticated users can verify admin status"
on public.app_admins for select to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_admin())
);

-- Seed existing verified user if present
insert into public.app_admins (user_id, email)
select id, email from auth.users
where email in ('dhuamanich@unsa.edu.pe', 'udeeg_convocatorias@unsa.edu.pe')
on conflict (user_id) do nothing;

-- Update RLS for Opportunities to support is_active and Admin Moderation
drop policy if exists "Verified UNSA users can read opportunities" on public.opportunities;
drop policy if exists "Verified UNSA users can read active opportunities" on public.opportunities;
drop policy if exists "Admins can update opportunities" on public.opportunities;

create policy "Verified UNSA users can read active opportunities"
on public.opportunities for select to authenticated
using (
  (select public.is_verified_unsa_user())
  and (is_active = true or (select public.is_admin()))
);

create policy "Admins can update opportunities"
on public.opportunities for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));

grant update on table public.opportunities to authenticated;

-- Admin access to source_emails and profiles
drop policy if exists "Admins can read source emails" on public.source_emails;
create policy "Admins can read source emails"
on public.source_emails for select to authenticated
using ((select public.is_admin()));

grant select on table public.source_emails to authenticated;

drop policy if exists "Admins can read all profiles" on public.profiles;
create policy "Admins can read all profiles"
on public.profiles for select to authenticated
using ((select public.is_admin()));

-- 3. Convocatorias Favoritas (Module A)
create table if not exists public.opportunity_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  opportunity_id uuid not null references public.opportunities (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint opportunity_favorites_user_opportunity_key unique (user_id, opportunity_id)
);

alter table public.opportunity_favorites enable row level security;
revoke all on table public.opportunity_favorites from anon, authenticated;
grant select, insert, delete on table public.opportunity_favorites to authenticated;

create policy "Verified UNSA users can read their own favorites"
on public.opportunity_favorites for select to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can add their own favorites"
on public.opportunity_favorites for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can remove their own favorites"
on public.opportunity_favorites for delete to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

-- 4. Seguimiento de Postulaciones (Module B)
create table if not exists public.job_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  opportunity_id uuid not null references public.opportunities (id) on delete cascade,
  status text not null default 'pendiente'
    check (status in ('pendiente', 'postulada', 'en evaluacion', 'seleccionada', 'no seleccionada')),
  notes text,
  applied_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint job_applications_user_opportunity_key unique (user_id, opportunity_id)
);

alter table public.job_applications enable row level security;
revoke all on table public.job_applications from anon, authenticated;
grant select, insert, update, delete on table public.job_applications to authenticated;

create policy "Verified UNSA users can read their own applications"
on public.job_applications for select to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can create their own applications"
on public.job_applications for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can update their own applications"
on public.job_applications for update to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
)
with check (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can delete their own applications"
on public.job_applications for delete to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create or replace function public.set_job_application_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists job_applications_set_updated_at on public.job_applications;
create trigger job_applications_set_updated_at
before update on public.job_applications
for each row execute function public.set_job_application_updated_at();

-- 5. Sistema de Notificaciones Internas (Module D)
create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (length(btrim(title)) > 0),
  message text not null check (length(btrim(message)) > 0),
  type text not null check (type in ('new_opportunity', 'closing_soon', 'application_update', 'system')),
  opportunity_id uuid references public.opportunities (id) on delete cascade,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint user_notifications_dedupe_key unique (user_id, type, opportunity_id)
);

alter table public.user_notifications enable row level security;
revoke all on table public.user_notifications from anon, authenticated;
grant select, insert, update, delete on table public.user_notifications to authenticated;

create policy "Verified UNSA users can read their own notifications"
on public.user_notifications for select to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can create their own notifications"
on public.user_notifications for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can update their own notifications"
on public.user_notifications for update to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
)
with check (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Verified UNSA users can delete their own notifications"
on public.user_notifications for delete to authenticated
using (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create or replace function public.sync_user_notifications(p_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted_count integer := 0;
  v_temp_count integer := 0;
begin
  if p_user_id is null or p_user_id <> (select auth.uid()) then
    if not (select public.is_admin()) then
      return 0;
    end if;
  end if;

  -- 1. Notificaciones de cierre próximo (dentro de 3 días)
  insert into public.user_notifications (user_id, title, message, type, opportunity_id)
  select
    p_user_id,
    'Próximo cierre de convocatoria',
    'La convocatoria "' || coalesce(o.title, 'Oportunidad') || '" en ' || coalesce(o.company, 'la entidad convocante') || ' cierra el ' || to_char(o.closing_date, 'DD/MM/YYYY') || '.',
    'closing_soon',
    o.id
  from public.opportunities o
  where o.is_active = true
    and o.closing_date is not null
    and o.closing_date >= current_date
    and o.closing_date <= (current_date + interval '3 days')
    and not exists (
      select 1 from public.user_notifications n
      where n.user_id = p_user_id
        and n.type = 'closing_soon'
        and n.opportunity_id = o.id
    )
  on conflict (user_id, type, opportunity_id) do nothing;
  get diagnostics v_temp_count = row_count;
  v_inserted_count := v_inserted_count + v_temp_count;

  -- 2. Notificaciones de nuevas oportunidades activas
  insert into public.user_notifications (user_id, title, message, type, opportunity_id)
  select
    p_user_id,
    'Nueva convocatoria disponible',
    'Se publicó "' || coalesce(o.title, 'Oportunidad') || '" en ' || coalesce(o.company, 'UDEEG UNSA') || '.',
    'new_opportunity',
    o.id
  from public.opportunities o
  where o.is_active = true
    and (o.closing_date is null or o.closing_date >= current_date)
    and not exists (
      select 1 from public.user_notifications n
      where n.user_id = p_user_id
        and n.type = 'new_opportunity'
        and n.opportunity_id = o.id
    )
  on conflict (user_id, type, opportunity_id) do nothing;
  get diagnostics v_temp_count = row_count;
  v_inserted_count := v_inserted_count + v_temp_count;

  return v_inserted_count;
end;
$$;

revoke all on function public.sync_user_notifications(uuid) from public;
grant execute on function public.sync_user_notifications(uuid) to authenticated;

-- 6. Reportes de Incidencias / Información Incorrecta (Module E)
create table if not exists public.opportunity_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  opportunity_id uuid not null references public.opportunities (id) on delete cascade,
  reason text not null check (length(btrim(reason)) > 0),
  status text not null default 'pending'
    check (status in ('pending', 'resolved', 'dismissed')),
  admin_notes text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

alter table public.opportunity_reports enable row level security;
revoke all on table public.opportunity_reports from anon, authenticated;
grant select, insert, update on table public.opportunity_reports to authenticated;

create policy "Verified users can create opportunity reports"
on public.opportunity_reports for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (select public.is_verified_unsa_user())
);

create policy "Users can view their own reports"
on public.opportunity_reports for select to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_admin())
);

create policy "Admins can update reports"
on public.opportunity_reports for update to authenticated
using ((select public.is_admin()))
with check ((select public.is_admin()));
