create or replace function public.ingest_opportunities(
  p_source_email jsonb,
  p_opportunities jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_message_id text;
  v_source_email_id uuid;
  v_status text;
  v_count integer;
  v_email_field text;
  v_opportunity_field text;
  v_opportunity jsonb;
  v_position bigint;
  v_opportunity_id uuid;
  v_careers jsonb;
  v_career jsonb;
  v_original_career text;
  v_canonical_career text;
  v_match_count integer;
  v_received_at_text text;
  v_received_at timestamptz;
  v_closing_date_text text;
  v_closing_date date;
  v_vacancies integer;
  v_vacancies_numeric numeric;
  v_sqlstate text;
  v_error_code text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception using
      errcode = '42501',
      message = 'Only the service role may execute this function';
  end if;

  if jsonb_typeof(p_source_email) is distinct from 'object'
     or jsonb_typeof(p_source_email -> 'gmail_message_id') is distinct from 'string'
     or nullif(btrim(p_source_email ->> 'gmail_message_id'), '') is null then
    return jsonb_build_object(
      'ok', false,
      'error_code', 'invalid_gmail_message_id'
    );
  end if;

  v_message_id := btrim(p_source_email ->> 'gmail_message_id');

  insert into public.source_emails (gmail_message_id)
  values (v_message_id)
  on conflict (gmail_message_id) do nothing
  returning id, processing_status into v_source_email_id, v_status;

  if v_source_email_id is null then
    select id, processing_status
      into v_source_email_id, v_status
      from public.source_emails
      where gmail_message_id = v_message_id
      for update;
  end if;

  if v_status = 'processed' then
    select count(*)::integer
      into v_count
      from public.opportunities
      where source_email_id = v_source_email_id;

    return jsonb_build_object(
      'ok', true,
      'duplicate', true,
      'gmail_message_id', v_message_id,
      'opportunity_count', v_count
    );
  end if;

  begin
    foreach v_email_field in array array[
      'sender_email', 'subject', 'received_at', 'original_body'
    ] loop
      if p_source_email ? v_email_field
         and jsonb_typeof(p_source_email -> v_email_field)
             not in ('string', 'null') then
        raise exception using
          errcode = '22023',
          message = format('source_email.%s must be a string or null', v_email_field);
      end if;
    end loop;

    if jsonb_typeof(p_source_email -> 'original_body') is distinct from 'string'
       or length(btrim(p_source_email ->> 'original_body')) = 0 then
      raise exception using
        errcode = '22023',
        message = 'source_email.original_body is required';
    end if;

    update public.source_emails
      set sender_email = nullif(btrim(p_source_email ->> 'sender_email'), ''),
          subject = nullif(btrim(p_source_email ->> 'subject'), ''),
          received_at = null,
          original_body = p_source_email ->> 'original_body',
          processing_status = 'pending',
          processed_at = null,
          processing_error = null
      where id = v_source_email_id;
  exception when others then
    get stacked diagnostics v_sqlstate = returned_sqlstate;
    v_error_code := case
      when left(v_sqlstate, 2) = '22' then 'invalid_payload'
      else 'processing_failed'
    end;
    update public.source_emails
      set processing_status = 'error',
          processed_at = null,
          processing_error = case
            when v_error_code = 'invalid_payload'
              then 'The submitted source email failed validation.'
            else 'The source email could not be prepared for processing.'
          end
      where id = v_source_email_id;

    return jsonb_build_object(
      'ok', false,
      'error_code', v_error_code,
      'gmail_message_id', v_message_id
    );
  end;

  begin
    v_received_at := null;
    v_received_at_text := nullif(btrim(p_source_email ->> 'received_at'), '');
    if v_received_at_text is not null then
      -- Match the Edge contract: YYYY-MM-DDTHH:mm:ss, optional 1-6 digit
      -- fraction, and Z or a signed HH:MM offset no greater than 14:00.
      if v_received_at_text !~ '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,6})?(Z|([+]|-)(0[0-9]|1[0-3]):[0-5][0-9]|([+]|-)14:00)$' then
        raise exception using
          errcode = '22023',
          message = 'source_email.received_at must use the accepted ISO timestamp format';
      end if;
      v_received_at := v_received_at_text::timestamptz;
    end if;
    update public.source_emails
      set received_at = v_received_at
      where id = v_source_email_id;
  exception when others then
    get stacked diagnostics v_sqlstate = returned_sqlstate;
    v_error_code := case
      when left(v_sqlstate, 2) = '22' then 'invalid_payload'
      else 'processing_failed'
    end;
    update public.source_emails
      set processing_status = 'error',
          processed_at = null,
          processing_error = case
            when v_error_code = 'invalid_payload'
              then 'The source email received_at value is invalid.'
            else 'The source email timestamp could not be stored.'
          end
      where id = v_source_email_id;

    return jsonb_build_object(
      'ok', false,
      'error_code', v_error_code,
      'gmail_message_id', v_message_id
    );
  end;

  begin
    if jsonb_typeof(p_opportunities) is distinct from 'array' then
      raise exception using
        errcode = '22023',
        message = 'opportunities must be a JSON array';
    end if;

    delete from public.opportunities
      where source_email_id = v_source_email_id;

    for v_opportunity, v_position in
      select item.value, item.ordinality
      from jsonb_array_elements(p_opportunities)
        with ordinality as item(value, ordinality)
    loop
      if jsonb_typeof(v_opportunity) is distinct from 'object' then
        raise exception using
          errcode = '22023',
          message = 'Each opportunity must be a JSON object';
      end if;

      foreach v_opportunity_field in array array[
        'title', 'company', 'academic_profile', 'location', 'requirements',
        'desired_knowledge', 'functions', 'additional_information',
        'application_url', 'application_email', 'application_phone',
        'cv_type', 'original_content'
      ] loop
        if v_opportunity ? v_opportunity_field
           and jsonb_typeof(v_opportunity -> v_opportunity_field)
               not in ('string', 'null') then
          raise exception using
            errcode = '22023',
            message = format('opportunity.%s has an invalid JSON type', v_opportunity_field);
        end if;
      end loop;

      if jsonb_typeof(v_opportunity -> 'original_content') is distinct from 'string'
         or length(btrim(v_opportunity ->> 'original_content')) = 0 then
        raise exception using
          errcode = '22023',
          message = 'opportunity.original_content is required';
      end if;

      if v_opportunity ? 'closing_date'
         and jsonb_typeof(v_opportunity -> 'closing_date')
             not in ('string', 'null') then
        raise exception using
          errcode = '22023',
          message = 'opportunity.closing_date must be a date string or null';
      end if;
      v_closing_date := null;
      v_closing_date_text := nullif(btrim(v_opportunity ->> 'closing_date'), '');
      if v_closing_date_text is not null then
        -- Closing dates use the unambiguous YYYY-MM-DD form only.
        if v_closing_date_text !~ '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$' then
          raise exception using
            errcode = '22023',
            message = 'opportunity.closing_date must use the YYYY-MM-DD format';
        end if;
        v_closing_date := v_closing_date_text::date;
      end if;

      if v_opportunity ? 'vacancies'
         and jsonb_typeof(v_opportunity -> 'vacancies')
             not in ('number', 'null') then
        raise exception using
          errcode = '22023',
          message = 'opportunity.vacancies must be a positive integer or null';
      end if;
      v_vacancies := null;
      if jsonb_typeof(v_opportunity -> 'vacancies') = 'number' then
        v_vacancies_numeric := (v_opportunity ->> 'vacancies')::numeric;
        if v_vacancies_numeric <= 0
           or trunc(v_vacancies_numeric) <> v_vacancies_numeric
           or v_vacancies_numeric > 2147483647 then
          raise exception using
            errcode = '22023',
            message = 'opportunity.vacancies must be a positive integer';
        end if;
        v_vacancies := v_vacancies_numeric::integer;
      end if;

      insert into public.opportunities (
        source_email_id, source_position, title, company, academic_profile,
        location, closing_date, vacancies, requirements, desired_knowledge,
        functions, additional_information, application_url, application_email,
        application_phone, cv_type, original_content
      ) values (
        v_source_email_id,
        v_position::integer,
        nullif(btrim(v_opportunity ->> 'title'), ''),
        nullif(btrim(v_opportunity ->> 'company'), ''),
        nullif(btrim(v_opportunity ->> 'academic_profile'), ''),
        nullif(btrim(v_opportunity ->> 'location'), ''),
        v_closing_date,
        v_vacancies,
        nullif(btrim(v_opportunity ->> 'requirements'), ''),
        nullif(btrim(v_opportunity ->> 'desired_knowledge'), ''),
        nullif(btrim(v_opportunity ->> 'functions'), ''),
        nullif(btrim(v_opportunity ->> 'additional_information'), ''),
        nullif(btrim(v_opportunity ->> 'application_url'), ''),
        nullif(btrim(v_opportunity ->> 'application_email'), ''),
        nullif(btrim(v_opportunity ->> 'application_phone'), ''),
        nullif(btrim(v_opportunity ->> 'cv_type'), ''),
        v_opportunity ->> 'original_content'
      )
      returning id into v_opportunity_id;

      v_careers := v_opportunity -> 'careers';
      if v_careers is not null and jsonb_typeof(v_careers) <> 'null' then
        if jsonb_typeof(v_careers) is distinct from 'array' then
          raise exception using
            errcode = '22023',
            message = 'opportunity.careers must be an array of career names';
        end if;

        for v_career in select value from jsonb_array_elements(v_careers)
        loop
          if jsonb_typeof(v_career) is distinct from 'string'
             or length(btrim(v_career #>> '{}')) = 0 then
            raise exception using
              errcode = '22023',
              message = 'Each career name must be a non-empty string';
          end if;

          v_original_career := v_career #>> '{}';
          if exists (
            select 1
              from public.opportunity_careers
              where opportunity_id = v_opportunity_id
                and original_career_name = v_original_career
          ) then
            continue;
          end if;

          v_canonical_career := null;
          select count(*)::integer, min(career_name)
            into v_match_count, v_canonical_career
            from public.career_catalog
            where lower(btrim(career_name)) = lower(btrim(v_original_career));

          if v_match_count = 0 then
            select count(*)::integer, min(career_name)
              into v_match_count, v_canonical_career
              from public.career_aliases
              where lower(btrim(alias)) = lower(btrim(v_original_career));
          end if;

          if v_match_count <> 1 then
            v_canonical_career := null;
          end if;

          begin
            insert into public.opportunity_careers (
              opportunity_id, original_career_name, career_name
            ) values (
              v_opportunity_id, v_original_career, v_canonical_career
            );
          exception when unique_violation then
            -- If another source spelling maps to the same canonical career,
            -- preserve its original text without duplicating the canonical link.
            insert into public.opportunity_careers (
              opportunity_id, original_career_name, career_name
            ) values (
              v_opportunity_id, v_original_career, null
            ) on conflict (opportunity_id, original_career_name) do nothing;
          end;
        end loop;
      end if;
    end loop;

  exception when others then
    get stacked diagnostics v_sqlstate = returned_sqlstate;
    v_error_code := case
      when left(v_sqlstate, 2) = '22' then 'invalid_payload'
      else 'processing_failed'
    end;
    update public.source_emails
      set processing_status = 'error',
          processed_at = null,
          processing_error = case
            when v_error_code = 'invalid_payload'
              then 'The opportunity payload failed validation.'
            else 'The opportunities could not be stored.'
          end
      where id = v_source_email_id;

    return jsonb_build_object(
      'ok', false,
      'error_code', v_error_code,
      'gmail_message_id', v_message_id
    );
  end;

  update public.source_emails
    set processing_status = 'processed',
        processed_at = now(),
        processing_error = null
    where id = v_source_email_id;

  return jsonb_build_object(
    'ok', true,
    'duplicate', false,
    'gmail_message_id', v_message_id,
    'opportunity_count', jsonb_array_length(p_opportunities)
  );
end;
$$;

revoke all on function public.ingest_opportunities(jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.ingest_opportunities(jsonb, jsonb)
  to service_role;

comment on function public.ingest_opportunities(jsonb, jsonb) is
  'Atomically ingests one Gmail source message and its opportunities; executable only by service_role.';

create or replace function public.mark_opportunity_ingest_error(
  p_gmail_message_id text,
  p_error_code text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_safe_error text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception using
      errcode = '42501',
      message = 'Only the service role may execute this function';
  end if;

  if p_gmail_message_id is null
     or nullif(btrim(p_gmail_message_id), '') is null then
    return false;
  end if;

  v_safe_error := case p_error_code
    when 'invalid_payload' then 'The incoming payload failed validation.'
    when 'ingest_rpc_error' then 'The opportunity ingestion RPC failed.'
    else null
  end;

  if v_safe_error is null then
    return false;
  end if;

  insert into public.source_emails (gmail_message_id)
  values (btrim(p_gmail_message_id))
  on conflict (gmail_message_id) do nothing;

  update public.source_emails
    set processing_status = 'error',
        processed_at = null,
        processing_error = v_safe_error
    where gmail_message_id = btrim(p_gmail_message_id)
      and processing_status <> 'processed';

  return found;
end;
$$;

revoke all on function public.mark_opportunity_ingest_error(text, text)
  from public, anon, authenticated;
grant execute on function public.mark_opportunity_ingest_error(text, text)
  to service_role;

comment on function public.mark_opportunity_ingest_error(text, text) is
  'Best-effort, service_role-only registration of a safe ingestion error; never downgrades a processed email.';
