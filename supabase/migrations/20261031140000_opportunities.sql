create table public.career_catalog (
  career_name text primary key
    check (length(btrim(career_name)) > 0)
);

insert into public.career_catalog (career_name) values
  ('Arquitectura'),
  ('Ingeniería Ambiental'),
  ('Ingeniería Civil'),
  ('Ingeniería de Industrias Alimentarias'),
  ('Ingeniería de Materiales'),
  ('Ingeniería de Minas'),
  ('Ingeniería de Sistemas'),
  ('Ingeniería de Telecomunicaciones'),
  ('Ingeniería Eléctrica'),
  ('Ingeniería Electrónica'),
  ('Ingeniería Geofísica'),
  ('Ingeniería Geológica'),
  ('Ingeniería Industrial'),
  ('Ingeniería Mecánica'),
  ('Ingeniería Metalúrgica'),
  ('Ingeniería Pesquera'),
  ('Ingeniería Química'),
  ('Ingeniería Sanitaria'),
  ('Antropología'),
  ('Artes - Música'),
  ('Artes - Artes Plásticas'),
  ('Ciencias de la Comunicación - Periodismo'),
  ('Ciencias de la Comunicación - Relaciones Públicas'),
  ('Derecho'),
  ('Educación - Inicial'),
  ('Educación - Primaria'),
  ('Educación - Secundaria'),
  ('Educación - Física'),
  ('Filosofía'),
  ('Historia'),
  ('Literatura y Lingüística'),
  ('Psicología'),
  ('Relaciones Industriales'),
  ('Sociología'),
  ('Trabajo Social'),
  ('Turismo y Hotelería'),
  ('Agronomía'),
  ('Biología'),
  ('Ciencias de la Nutrición'),
  ('Enfermería'),
  ('Medicina'),
  ('Ciencia de la Computación'),
  ('Física'),
  ('Matemáticas'),
  ('Química'),
  ('Administración'),
  ('Banca y Seguros'),
  ('Contabilidad'),
  ('Economía'),
  ('Finanzas'),
  ('Gestión'),
  ('Marketing')
on conflict (career_name) do nothing;

create table public.career_aliases (
  alias text primary key
    check (length(btrim(alias)) > 0),
  career_name text not null
    references public.career_catalog (career_name) on delete restrict
);

create unique index career_aliases_normalized_alias_key
  on public.career_aliases (lower(btrim(alias)));

create table public.source_emails (
  id uuid primary key default gen_random_uuid(),
  gmail_message_id text not null unique
    check (length(btrim(gmail_message_id)) > 0),
  sender_email text,
  subject text,
  received_at timestamptz,
  original_body text
);

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  source_email_id uuid not null
    references public.source_emails (id) on delete restrict,
  source_position integer not null check (source_position > 0),
  title text,
  company text,
  academic_profile text,
  location text,
  closing_date date,
  vacancies integer check (vacancies is null or vacancies > 0),
  requirements text,
  desired_knowledge text,
  functions text,
  additional_information text,
  application_url text,
  cv_type text,
  original_content text not null
    check (length(btrim(original_content)) > 0),
  constraint opportunities_source_position_key
    unique (source_email_id, source_position)
);

create index opportunities_closing_date_idx
  on public.opportunities (closing_date)
  where closing_date is not null;

create table public.opportunity_careers (
  opportunity_id uuid not null
    references public.opportunities (id) on delete cascade,
  original_career_name text not null
    check (length(btrim(original_career_name)) > 0),
  career_name text
    references public.career_catalog (career_name) on delete restrict,
  primary key (opportunity_id, original_career_name)
);

create unique index opportunity_careers_canonical_key
  on public.opportunity_careers (opportunity_id, career_name)
  where career_name is not null;

create index opportunity_careers_career_name_idx
  on public.opportunity_careers (career_name)
  where career_name is not null;

alter table public.career_catalog enable row level security;
alter table public.career_aliases enable row level security;
alter table public.source_emails enable row level security;
alter table public.opportunities enable row level security;
alter table public.opportunity_careers enable row level security;

revoke all on table
  public.career_catalog,
  public.career_aliases,
  public.source_emails,
  public.opportunities,
  public.opportunity_careers
from anon, authenticated;

grant select on table
  public.career_catalog,
  public.opportunities,
  public.opportunity_careers
to authenticated;

create policy "Verified UNSA users can read the career catalog"
on public.career_catalog for select to authenticated
using ((select public.is_verified_unsa_user()));

create policy "Verified UNSA users can read opportunities"
on public.opportunities for select to authenticated
using ((select public.is_verified_unsa_user()));

create policy "Verified UNSA users can read opportunity careers"
on public.opportunity_careers for select to authenticated
using ((select public.is_verified_unsa_user()));
