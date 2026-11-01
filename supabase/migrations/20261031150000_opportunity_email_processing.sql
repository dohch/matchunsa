alter table public.opportunities
  add column application_email text,
  add column application_phone text;

comment on column public.opportunities.application_email is
  'Correo de contacto para postular, cuando aparece en la convocatoria de origen.';
comment on column public.opportunities.application_phone is
  'Teléfono de contacto para postular, cuando aparece en la convocatoria de origen.';

alter table public.source_emails
  add column processing_status text not null default 'pending'
    check (processing_status in ('pending', 'processed', 'error')),
  add column processed_at timestamptz,
  add column processing_error text;

comment on column public.source_emails.processing_status is
  'Estado de procesamiento del mensaje por la integración: pending, processed o error.';
comment on column public.source_emails.processed_at is
  'Fecha y hora en que terminó correctamente el procesamiento del mensaje.';
comment on column public.source_emails.processing_error is
  'Descripción del último error de procesamiento, si ocurrió alguno.';
