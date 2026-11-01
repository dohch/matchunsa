create or replace function public.reprocess_opportunities_for_email(
  p_gmail_message_id text,
  p_opportunities jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_email public.source_emails%rowtype;
  v_source_payload jsonb;
  v_result jsonb;
  v_expected_count integer;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception using
      errcode = '42501',
      message = 'Only the service role may execute this function';
  end if;

  if p_gmail_message_id is null
     or nullif(btrim(p_gmail_message_id), '') is null
     or p_gmail_message_id <> btrim(p_gmail_message_id) then
    return jsonb_build_object('ok', false, 'error_code', 'invalid_gmail_message_id');
  end if;

  if jsonb_typeof(p_opportunities) is distinct from 'array' then
    return jsonb_build_object('ok', false, 'error_code', 'invalid_opportunities');
  end if;

  if jsonb_array_length(p_opportunities) = 0 then
    return jsonb_build_object('ok', false, 'error_code', 'invalid_opportunities');
  end if;

  select source_email.*
    into v_source_email
    from public.source_emails as source_email
    where source_email.gmail_message_id = p_gmail_message_id
    for update;

  if not found then
    return jsonb_build_object('ok', false, 'error_code', 'source_email_not_found');
  end if;

  if lower(btrim(coalesce(v_source_email.sender_email, '')))
       <> 'udeeg_convocatorias@unsa.edu.pe' then
    return jsonb_build_object('ok', false, 'error_code', 'source_email_not_udeeg');
  end if;

  if v_source_email.processing_status <> 'processed' then
    return jsonb_build_object('ok', false, 'error_code', 'source_email_not_processed');
  end if;

  v_expected_count := jsonb_array_length(p_opportunities);

  -- The original source record stays in place. Its processing state changes are
  -- inside this RPC transaction and are rolled back if the normal ingest fails.
  update public.source_emails
    set processing_status = 'pending',
        processed_at = null,
        processing_error = null
    where id = v_source_email.id;

  v_source_payload := jsonb_build_object(
    'gmail_message_id', v_source_email.gmail_message_id,
    'sender_email', v_source_email.sender_email,
    'subject', v_source_email.subject,
    'received_at', case
      when v_source_email.received_at is null then null
      else to_char(
        v_source_email.received_at at time zone 'UTC',
        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
      )
    end,
    'original_body', v_source_email.original_body
  );

  -- ingest_opportunities performs the scoped delete and inserts inside its
  -- own exception block. Any non-success result is raised here so PostgreSQL
  -- rolls back this entire outer RPC, including the delete and state changes.
  v_result := public.ingest_opportunities(v_source_payload, p_opportunities);

  if jsonb_typeof(v_result) is distinct from 'object'
     or v_result ->> 'ok' is distinct from 'true'
     or v_result ->> 'duplicate' is distinct from 'false'
     or v_result ->> 'gmail_message_id' is distinct from p_gmail_message_id
     or jsonb_typeof(v_result -> 'opportunity_count') is distinct from 'number'
     or (v_result ->> 'opportunity_count')::numeric <> v_expected_count::numeric then
    raise exception using
      errcode = 'P0001',
      message = 'Opportunity reprocessing failed; all changes were rolled back';
  end if;

  -- Restore all immutable source fields exactly as they were before calling
  -- the normal ingestion path; only the processing timestamp is refreshed.
  update public.source_emails
    set sender_email = v_source_email.sender_email,
        subject = v_source_email.subject,
        received_at = v_source_email.received_at,
        original_body = v_source_email.original_body,
        processing_status = 'processed',
        processed_at = now(),
        processing_error = null
    where id = v_source_email.id;

  return jsonb_build_object(
    'ok', true,
    'reprocessed', true,
    'gmail_message_id', p_gmail_message_id,
    'opportunity_count', v_expected_count
  );
end;
$$;

revoke all on function public.reprocess_opportunities_for_email(text, jsonb)
  from public, anon, authenticated;
grant execute on function public.reprocess_opportunities_for_email(text, jsonb)
  to service_role;

comment on function public.reprocess_opportunities_for_email(text, jsonb) is
  'Atomically replaces opportunities for one already-processed UDEEG Gmail message; service_role only.';
