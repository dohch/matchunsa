begin;

select plan(1);

select lives_ok($execution$
do $test$
declare
  v_target_id constant text := 'local-test-udeeg-reprocess-target';
  v_other_id constant text := 'local-test-udeeg-reprocess-other';
  v_pending_id constant text := 'local-test-udeeg-reprocess-pending';
  v_error_id constant text := 'local-test-udeeg-reprocess-error';
  v_non_udeeg_id constant text := 'local-test-non-udeeg-reprocess';
  v_target_source_id uuid;
  v_other_source_id uuid;
  v_original_body constant text := 'Correo UDEEG original para prueba local';
  v_result jsonb;
  v_error text;
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);

  v_result := public.ingest_opportunities(
    jsonb_build_object(
      'gmail_message_id', v_target_id,
      'sender_email', 'udeeg_convocatorias@unsa.edu.pe',
      'subject', 'OSMIOZ original',
      'received_at', '2026-10-31T12:00:00.000000Z',
      'original_body', v_original_body
    ),
    jsonb_build_array(
      jsonb_build_object('title', 'Antigua 1', 'original_content', 'Original 1', 'careers', jsonb_build_array('Arquitectura')),
      jsonb_build_object('title', 'Antigua 2', 'original_content', 'Original 2', 'careers', jsonb_build_array('Derecho')),
      jsonb_build_object('title', 'Antigua 3', 'original_content', 'Original 3', 'careers', jsonb_build_array('Medicina')),
      jsonb_build_object('title', 'Antigua 4', 'original_content', 'Original 4', 'careers', jsonb_build_array('Economía'))
    )
  );
  if v_result ->> 'ok' is distinct from 'true' then
    raise exception 'No se pudo preparar el correo objetivo de prueba.';
  end if;

  v_result := public.ingest_opportunities(
    jsonb_build_object(
      'gmail_message_id', v_other_id,
      'sender_email', 'udeeg_convocatorias@unsa.edu.pe',
      'subject', 'Otro correo',
      'original_body', 'Correo diferente que no debe modificarse'
    ),
    jsonb_build_array(
      jsonb_build_object('title', 'No tocar', 'original_content', 'Convocatoria ajena', 'careers', jsonb_build_array('Física'))
    )
  );
  if v_result ->> 'ok' is distinct from 'true' then
    raise exception 'No se pudo preparar el correo independiente de prueba.';
  end if;

  select id into v_target_source_id
    from public.source_emails where gmail_message_id = v_target_id;
  select id into v_other_source_id
    from public.source_emails where gmail_message_id = v_other_id;

  v_result := public.reprocess_opportunities_for_email(
    v_target_id,
    jsonb_build_array(
      jsonb_build_object('title', 'Nueva 1', 'original_content', 'Actualizada 1', 'careers', jsonb_build_array('Ingeniería Civil')),
      jsonb_build_object('title', 'Nueva 2', 'original_content', 'Actualizada 2', 'careers', jsonb_build_array('Ingeniería de Sistemas')),
      jsonb_build_object('title', 'Nueva 3', 'original_content', 'Actualizada 3', 'careers', jsonb_build_array('Psicología')),
      jsonb_build_object('title', 'Nueva 4', 'original_content', 'Actualizada 4', 'careers', jsonb_build_array('Economía'))
    )
  );
  if v_result ->> 'ok' is distinct from 'true'
     or v_result ->> 'reprocessed' is distinct from 'true'
     or v_result ->> 'gmail_message_id' is distinct from v_target_id
     or (v_result ->> 'opportunity_count')::integer <> 4 then
    raise exception 'El reprocesamiento no confirmó el ID y cantidad esperados.';
  end if;

  if (select count(*) from public.opportunities where source_email_id = v_target_source_id) <> 4
     or exists (
       select 1 from public.opportunities
       where source_email_id = v_target_source_id and title like 'Antigua %'
     )
     or (select count(*) from public.opportunity_careers career
         join public.opportunities opportunity
           on opportunity.id = career.opportunity_id
         where opportunity.source_email_id = v_target_source_id) <> 4 then
    raise exception 'Las oportunidades o carreras objetivo no fueron reemplazadas exactamente.';
  end if;

  if (select count(*) from public.opportunities where source_email_id = v_other_source_id) <> 1
     or not exists (
       select 1 from public.opportunities
       where source_email_id = v_other_source_id and title = 'No tocar'
     ) then
    raise exception 'El reprocesamiento modificó el correo independiente.';
  end if;

  if not exists (
    select 1 from public.source_emails
    where id = v_target_source_id
      and gmail_message_id = v_target_id
      and sender_email = 'udeeg_convocatorias@unsa.edu.pe'
      and subject = 'OSMIOZ original'
      and original_body = v_original_body
      and processing_status = 'processed'
  ) then
    raise exception 'El registro original de source_emails no se conservó.';
  end if;

  -- The normal RPC reports this invalid payload as a JSON error after its
  -- protected replacement block rolls back. The administrative RPC must raise,
  -- causing the outer transaction to roll back as well.
  begin
    perform public.reprocess_opportunities_for_email(
      v_target_id,
      jsonb_build_array(
        jsonb_build_object('title', 'No debe guardarse', 'original_content', 'Invalid vacancies', 'vacancies', 0)
      )
    );
    raise exception 'Expected reprocessing failure did not occur.';
  exception when others then
    get stacked diagnostics v_error = message_text;
    if v_error = 'Expected reprocessing failure did not occur.' then
      raise;
    end if;
  end;

  if (select count(*) from public.opportunities
      where source_email_id = v_target_source_id and title like 'Nueva %') <> 4
     or (select processing_status from public.source_emails where id = v_target_source_id)
        is distinct from 'processed' then
    raise exception 'Un error no revirtió el reemplazo ni conservó el estado anterior.';
  end if;

  insert into public.source_emails (
    gmail_message_id, sender_email, subject, original_body, processing_status
  ) values
    (v_pending_id, 'udeeg_convocatorias@unsa.edu.pe', 'Pendiente', 'Original', 'pending'),
    (v_error_id, 'udeeg_convocatorias@unsa.edu.pe', 'Fallido', 'Original', 'error');

  v_result := public.reprocess_opportunities_for_email(
    v_pending_id,
    jsonb_build_array(jsonb_build_object('original_content', 'No debe reprocesarse'))
  );
  if v_result ->> 'error_code' is distinct from 'source_email_not_processed' then
    raise exception 'Se aceptó incorrectamente un correo pendiente.';
  end if;

  v_result := public.reprocess_opportunities_for_email(
    v_error_id,
    jsonb_build_array(jsonb_build_object('original_content', 'No debe reprocesarse'))
  );
  if v_result ->> 'error_code' is distinct from 'source_email_not_processed' then
    raise exception 'Se aceptó incorrectamente un correo en estado error.';
  end if;

  v_result := public.reprocess_opportunities_for_email(
    'no-existe',
    jsonb_build_array(jsonb_build_object('original_content', 'No debe reprocesarse'))
  );
  if v_result ->> 'error_code' is distinct from 'source_email_not_found' then
    raise exception 'Se aceptó incorrectamente un Gmail message ID inexistente.';
  end if;

  v_result := public.ingest_opportunities(
    jsonb_build_object(
      'gmail_message_id', v_non_udeeg_id,
      'sender_email', 'otra-cuenta@example.com',
      'subject', 'No UDEEG',
      'original_body', 'Correo que no pertenece a UDEEG'
    ),
    jsonb_build_array(jsonb_build_object('title', 'Ajena', 'original_content', 'No UDEEG'))
  );
  if v_result ->> 'ok' is distinct from 'true' then
    raise exception 'No se pudo preparar el correo no UDEEG de prueba.';
  end if;
  v_result := public.reprocess_opportunities_for_email(
    v_non_udeeg_id,
    jsonb_build_array(jsonb_build_object('original_content', 'No debe reprocesarse'))
  );
  if v_result ->> 'error_code' is distinct from 'source_email_not_udeeg' then
    raise exception 'Se aceptó incorrectamente un correo que no es UDEEG.';
  end if;

  perform set_config('request.jwt.claims', '{"role":"authenticated"}', true);
  begin
    perform public.reprocess_opportunities_for_email(
      v_target_id,
      jsonb_build_array(jsonb_build_object('original_content', 'No autorizado'))
    );
    raise exception 'Expected permission failure did not occur.';
  exception when insufficient_privilege then
    null;
  end;
end;
$test$;
$execution$, 'reprocessing replaces only the requested email and rolls back failures');

select * from finish();

rollback;
