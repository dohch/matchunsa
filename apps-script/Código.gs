/**
 * MatchUNSA Gmail → Supabase ingestion.
 *
 * Configure SUPABASE_FUNCTION_URL and INGEST_SHARED_SECRET in
 * Apps Script → Project Settings → Script Properties. This script only reads
 * Gmail messages; it never labels, marks read, moves, or deletes them.
 */

const MATCHUNSA_SOURCE_QUERY = 'from:udeeg_convocatorias@unsa.edu.pe';
const MATCHUNSA_LOCAL_PROCESSED_PREFIX = 'MATCHUNSA_PROCESSED_GMAIL_';
const MATCHUNSA_SEARCH_PAGE_SIZE = 50;
const MATCHUNSA_AUTOMATION_START_PROPERTY = 'MATCHUNSA_AUTOMATION_START_MS';
const MATCHUNSA_LAST_SCAN_PROPERTY = 'MATCHUNSA_LAST_SCAN_MS';
const MATCHUNSA_RETRY_IDS_PROPERTY = 'MATCHUNSA_RETRY_GMAIL_IDS';
const MATCHUNSA_SCAN_OVERLAP_MS = 2 * 24 * 60 * 60 * 1000;

/** Reads new UDEEG messages and sends each unprocessed message to Supabase. */
function processNewUdeegEmails() {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  const scanStartedAt = Date.now();
  const results = [];
  const errors = [];
  const seenMessageIds = new Set();
  let found = 0;
  let processed = 0;
  let skipped = 0;
  let opportunitiesExtracted = 0;
  let scanCompleted = false;
  let properties = null;
  let startTimestamp = NaN;
  let retryIds = new Set();

  try {
    properties = PropertiesService.getScriptProperties();
    startTimestamp = Number(
      properties.getProperty(MATCHUNSA_AUTOMATION_START_PROPERTY),
    );
    if (!Number.isFinite(startTimestamp) || startTimestamp <= 0) {
      startTimestamp = scanStartedAt;
      properties.setProperty(
        MATCHUNSA_AUTOMATION_START_PROPERTY,
        String(startTimestamp),
      );
    }

    const storedRetryIds = properties.getProperty(MATCHUNSA_RETRY_IDS_PROPERTY);
    if (storedRetryIds) {
      try {
        const parsedIds = JSON.parse(storedRetryIds);
        if (Array.isArray(parsedIds)) {
          retryIds = new Set(
            parsedIds.filter((id) => typeof id === 'string' && id.trim()),
          );
        }
      } catch (_error) {
        errors.push('No se pudo leer la cola local de reintentos.');
        Logger.log(errors[errors.length - 1]);
      }
    }

    const processMessage = (message) => {
      const messageId = message.getId();
      if (!messageId || seenMessageIds.has(messageId)) return;
      seenMessageIds.add(messageId);

      if (!isUdeegSender_(message.getFrom())) {
        retryIds.delete(messageId);
        return;
      }

      const receivedAt = message.getDate();
      if (!(receivedAt instanceof Date) || Number.isNaN(receivedAt.getTime())) {
        retryIds.add(messageId);
        const error = 'No se pudo leer la fecha del correo.';
        errors.push(messageId + ': ' + error);
        Logger.log('Error procesando Gmail Message ID ' + messageId + ': ' + error);
        results.push({ ok: false, gmail_message_id: messageId, error: error });
        return;
      }
      if (receivedAt.getTime() < startTimestamp) {
        retryIds.delete(messageId);
        return;
      }

      found++;
      if (isLocallyProcessed_(messageId)) {
        skipped++;
        retryIds.delete(messageId);
        return;
      }

      try {
        const result = ingestGmailMessage_(message, (count) => {
          opportunitiesExtracted += count;
        });
        processed++;
        retryIds.delete(messageId);
        results.push(result);
      } catch (error) {
        retryIds.add(messageId);
        const messageText = error instanceof Error
          ? error.message
          : 'processing_failed';
        errors.push(messageId + ': ' + messageText);
        Logger.log(
          'Error procesando Gmail Message ID ' + messageId + ': ' + messageText,
        );
        results.push({
          ok: false,
          gmail_message_id: messageId,
          error: messageText,
        });
      }
    };

    for (const messageId of Array.from(retryIds)) {
      try {
        processMessage(GmailApp.getMessageById(messageId));
      } catch (error) {
        const messageText = error instanceof Error
          ? error.message
          : 'message_lookup_failed';
        errors.push(messageId + ': ' + messageText);
        Logger.log(
          'Error al reintentar Gmail Message ID ' + messageId + ': ' + messageText,
        );
      }
    }

    const lastScan = Number(properties.getProperty(MATCHUNSA_LAST_SCAN_PROPERTY));
    const checkpoint = Number.isFinite(lastScan) && lastScan > 0
      ? lastScan
      : startTimestamp;
    const searchFrom = Math.max(
      startTimestamp,
      checkpoint - MATCHUNSA_SCAN_OVERLAP_MS,
    );
    const query = MATCHUNSA_SOURCE_QUERY + ' after:' + _gmailAfterDate_(
      searchFrom - MATCHUNSA_SCAN_OVERLAP_MS,
    );

    let start = 0;
    while (true) {
      const threads = GmailApp.search(query, start, MATCHUNSA_SEARCH_PAGE_SIZE);
      if (threads.length === 0) break;
      threads.forEach((thread) => {
        thread.getMessages().forEach((message) => {
          processMessage(message);
        });
      });
      start += threads.length;
      if (threads.length < MATCHUNSA_SEARCH_PAGE_SIZE) break;
    }

    scanCompleted = true;
  } catch (error) {
    const messageText = error instanceof Error ? error.message : 'scan_failed';
    errors.push('Búsqueda de correo: ' + messageText);
    Logger.log('Error en la búsqueda de correos UDEEG: ' + messageText);
    results.push({ ok: false, error: 'scan_failed' });
  } finally {
    if (properties) {
      try {
        if (retryIds.size > 0) {
          properties.setProperty(
            MATCHUNSA_RETRY_IDS_PROPERTY,
            JSON.stringify(Array.from(retryIds)),
          );
        } else {
          properties.deleteProperty(MATCHUNSA_RETRY_IDS_PROPERTY);
        }
        if (scanCompleted) {
          properties.setProperty(
            MATCHUNSA_LAST_SCAN_PROPERTY,
            String(scanStartedAt),
          );
        }
      } catch (error) {
        const messageText = error instanceof Error
          ? error.message
          : 'state_persistence_failed';
        errors.push('No se pudo guardar el estado local: ' + messageText);
        Logger.log('Error guardando estado local de UDEEG: ' + messageText);
      }
    }

    Logger.log(
      'Resumen UDEEG: encontrados=' + found +
        ', procesados=' + processed +
        ', omitidos_por_marcador=' + skipped +
        ', convocatorias_extraídas=' + opportunitiesExtracted +
        ', errores=' + errors.length,
    );
    errors.forEach((error) => Logger.log('Error UDEEG: ' + error));
    lock.releaseLock();
  }

  return results;
}

/** Installs exactly one five-minute trigger for new UDEEG mail. */
function configurarActivadorUdeegCada5Minutos() {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const properties = PropertiesService.getScriptProperties();
    let startTimestamp = Number(
      properties.getProperty(MATCHUNSA_AUTOMATION_START_PROPERTY),
    );
    if (!Number.isFinite(startTimestamp) || startTimestamp <= 0) {
      startTimestamp = Date.now();
      properties.setProperty(
        MATCHUNSA_AUTOMATION_START_PROPERTY,
        String(startTimestamp),
      );
      properties.setProperty(
        MATCHUNSA_LAST_SCAN_PROPERTY,
        String(startTimestamp),
      );
    }

    const existingTriggers = ScriptApp.getProjectTriggers().filter(
      (trigger) => trigger.getHandlerFunction() === 'processNewUdeegEmails',
    );
    existingTriggers.forEach((trigger) => ScriptApp.deleteTrigger(trigger));
    ScriptApp.newTrigger('processNewUdeegEmails')
      .timeBased()
      .everyMinutes(5)
      .create();

    const message =
      'Activador UDEEG configurado cada 5 minutos. Activadores previos reemplazados: ' +
      existingTriggers.length +
      '. Correos anteriores a la activación quedan fuera del procesamiento.';
    Logger.log(message);
    return message;
  } finally {
    lock.releaseLock();
  }
}

function _gmailAfterDate_(timestamp) {
  const date = new Date(Math.max(0, timestamp));
  return [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, '0'),
    String(date.getUTCDate()).padStart(2, '0'),
  ].join('/');
}

/** Finds and processes only the newest message from the exact UDEEG address. */
function testLatestUdeegEmail() {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    let latest = null;
    let start = 0;
    while (true) {
      const threads = GmailApp.search(
        MATCHUNSA_SOURCE_QUERY,
        start,
        MATCHUNSA_SEARCH_PAGE_SIZE,
      );
      if (threads.length === 0) break;
      threads.forEach((thread) => {
        thread.getMessages().forEach((message) => {
          if (!isUdeegSender_(message.getFrom())) return;
          if (!latest || message.getDate().getTime() > latest.getDate().getTime()) {
            latest = message;
          }
        });
      });
      start += threads.length;
      if (threads.length < MATCHUNSA_SEARCH_PAGE_SIZE) break;
    }

    if (!latest) throw new Error('No se encontró un mensaje del remitente UDEEG exacto.');
    const messageId = latest.getId();
    let result;
    try {
      result = ingestGmailMessage_(latest);
    } catch (error) {
      result = {
        ok: false,
        error: error instanceof Error ? error.message : 'processing_failed',
      };
    }
    Logger.log(JSON.stringify({ gmail_message_id: messageId, result: result }));
    return result;
  } finally {
    lock.releaseLock();
  }
}

/** Logs diagnostic details for the latest exact UDEEG sender message only. */
function diagnosticarUltimoCorreoUdeeg() {
  let latest = null;
  let start = 0;
  while (true) {
    const threads = GmailApp.search(
      MATCHUNSA_SOURCE_QUERY,
      start,
      MATCHUNSA_SEARCH_PAGE_SIZE,
    );
    if (threads.length === 0) break;
    threads.forEach((thread) => {
      thread.getMessages().forEach((message) => {
        if (!isUdeegSender_(message.getFrom())) return;
        if (!latest || message.getDate().getTime() > latest.getDate().getTime()) {
          latest = message;
        }
      });
    });
    start += threads.length;
    if (threads.length < MATCHUNSA_SEARCH_PAGE_SIZE) break;
  }

  if (!latest) {
    throw new Error('No se encontró un correo de udeeg_convocatorias@unsa.edu.pe.');
  }

  const subject = latest.getSubject() || '';
  const sender = latest.getFrom() || '';
  const date = latest.getDate();
  const body = latest.getPlainBody() || '';
  const dateText = date instanceof Date ? date.toISOString() : String(date);

  Logger.log('Asunto: ' + subject);
  Logger.log('Remitente: ' + sender);
  Logger.log('Fecha: ' + dateText);
  Logger.log('Longitud del cuerpo: ' + body.length);
  Logger.log('Primeras 3000 letras del cuerpo:\n' + body.slice(0, 3000));

  const matchingLines = body.split(/\r?\n/).filter((line) => {
    const normalized = normalizeLabel_(line);
    return /\b(?:convocatorias?|laboral|practic\w*)\b/.test(normalized);
  });
  Logger.log('Líneas con palabras relacionadas (' + matchingLines.length + '):');
  matchingLines.forEach((line) => Logger.log(line));

  return {
    gmail_message_id: latest.getId(),
    subject: subject,
    sender: sender,
    received_at: dateText,
    body_length: body.length,
    matching_lines: matchingLines.length,
  };
}

/** Diagnoses parsed fields for the OSMIOZ message without sending or changing data. */
function diagnosticarCamposOSMIOZ() {
  const gmailMessageId = '1a18e9e617d73530';
  const message = GmailApp.getMessageById(gmailMessageId);
  if (!isUdeegSender_(message.getFrom())) {
    throw new Error('El mensaje indicado no pertenece al remitente UDEEG exacto.');
  }

  const originalBody = message.getPlainBody();
  if (typeof originalBody !== 'string' || !originalBody.trim()) {
    throw new Error('El correo no contiene un cuerpo de texto legible.');
  }

  const opportunities = extractOpportunities_(originalBody);
  Logger.log('Convocatorias detectadas: ' + opportunities.length);
  opportunities.forEach((opportunity, index) => {
    Logger.log('Convocatoria ' + (index + 1));
    Logger.log('Título: ' + (opportunity.title || 'null'));
    Logger.log('Empresa: ' + (opportunity.company || 'null'));
    Logger.log('Fecha de cierre: ' + (opportunity.closing_date || 'null'));
    Logger.log('Vacantes: ' + (opportunity.vacancies === null ? 'null' : opportunity.vacancies));
    Logger.log('Tipo de CV: ' + (opportunity.cv_type || 'null'));
    Logger.log('Requisitos completos:\n' + (opportunity.requirements || 'null'));
    Logger.log('Conocimientos deseables:\n' + (opportunity.desired_knowledge || 'null'));
  });

  if (opportunities.length !== 4) {
    throw new Error('Se esperaban exactamente 4 convocatorias; se detectaron ' + opportunities.length + '.');
  }

  const invalidCvTypes = opportunities
    .map((opportunity, index) => opportunity.cv_type === 'SIMPLE' ? null : index + 1)
    .filter((index) => index !== null);
  if (invalidCvTypes.length > 0) {
    throw new Error('Las convocatorias deben tener cv_type SIMPLE. Revisar: ' + invalidCvTypes.join(', ') + '.');
  }

  Logger.log('Validación completada: 4 convocatorias y cv_type SIMPLE en todas.');
  return { gmail_message_id: gmailMessageId, opportunity_count: opportunities.length, cv_type: 'SIMPLE' };
}

/**
 * Test entry point: processes exactly one message by its real Gmail message ID.
 * It does not modify or delete the Gmail message.
 */
function testProcessOneEmail(gmailMessageId) {
  if (typeof gmailMessageId !== 'string' || !gmailMessageId.trim()) {
    throw new Error('Proporciona el ID real de un mensaje de Gmail.');
  }

  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const message = GmailApp.getMessageById(gmailMessageId.trim());
    if (!isUdeegSender_(message.getFrom())) {
      throw new Error('El mensaje indicado no fue enviado por el remitente UDEEG exacto.');
    }
    return ingestGmailMessage_(message);
  } finally {
    lock.releaseLock();
  }
}

/**
 * Manually replaces opportunities for one already-processed UDEEG message.
 * This intentionally bypasses the local processed marker; it does not change it.
 */
function reprocesarCorreoUdeegPorId(gmailMessageId) {
  const loggedMessageId = typeof gmailMessageId === 'string' ? gmailMessageId : '(inválido)';
  let httpStatus = 'no disponible';
  let responseBody = 'no disponible';
  let lockAcquired = false;
  const lock = LockService.getScriptLock();
  try {
    if (
      typeof gmailMessageId !== 'string' ||
      !gmailMessageId.trim() ||
      gmailMessageId !== gmailMessageId.trim()
    ) {
      throw new Error('Proporciona el Gmail message ID exacto, sin espacios adicionales.');
    }

    lock.waitLock(30000);
    lockAcquired = true;
    const message = GmailApp.getMessageById(gmailMessageId);
    if (!isUdeegSender_(message.getFrom())) {
      throw new Error('El mensaje indicado no pertenece al remitente UDEEG exacto.');
    }

    const originalBody = message.getPlainBody();
    if (typeof originalBody !== 'string' || !originalBody.trim()) {
      throw new Error('El correo no contiene un cuerpo de texto legible.');
    }
    const opportunities = extractOpportunities_(originalBody);
    if (opportunities.length === 0) {
      throw new Error('No se encontraron convocatorias para reprocesar.');
    }
    if (gmailMessageId === '1a18e9e617d73530' && opportunities.length !== 4) {
      throw new Error(
        'El correo 1a18e9e617d73530 debe contener exactamente 4 convocatorias; ' +
          'se detectaron ' + opportunities.length + '. No se envió ninguna solicitud a Supabase.',
      );
    }

    const payload = buildReprocessPayload_(gmailMessageId, opportunities);
    validateReprocessOutgoingPayload_(payload);

    const properties = PropertiesService.getScriptProperties();
    const functionUrl = properties.getProperty('REPROCESS_FUNCTION_URL');
    const sharedSecret = properties.getProperty('REPROCESS_SHARED_SECRET');
    if (!functionUrl || !sharedSecret) {
      throw new Error(
        'Configura REPROCESS_FUNCTION_URL y REPROCESS_SHARED_SECRET en Script Properties.',
      );
    }

    const response = UrlFetchApp.fetch(functionUrl, {
      method: 'post',
      contentType: 'application/json',
      headers: { 'x-matchunsa-reprocess-secret': sharedSecret },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true,
    });
    httpStatus = response.getResponseCode();
    responseBody = response.getContentText();
    Logger.log('Reprocesamiento Gmail Message ID: ' + loggedMessageId);
    Logger.log('Respuesta HTTP de Supabase: ' + httpStatus);
    Logger.log('Cuerpo de respuesta de Supabase: ' + responseBody);

    const result = validateReprocessHttpResponse_(
      httpStatus,
      responseBody,
      gmailMessageId,
      opportunities.length,
    );
    Logger.log('Resultado final del reprocesamiento: éxito');
    return result;
  } catch (error) {
    Logger.log('Reprocesamiento Gmail Message ID: ' + loggedMessageId);
    Logger.log('Respuesta HTTP de Supabase: ' + httpStatus);
    Logger.log('Cuerpo de respuesta de Supabase: ' + responseBody);
    Logger.log(
      'Resultado final del reprocesamiento: error - ' +
        (error instanceof Error ? error.message : String(error)),
    );
    throw error;
  } finally {
    if (lockAcquired) lock.releaseLock();
  }
}

function buildReprocessPayload_(gmailMessageId, opportunities) {
  return {
    gmail_message_id: gmailMessageId,
    opportunities: opportunities,
  };
}

function validateReprocessOutgoingPayload_(payload) {
  if (
    !payload ||
    typeof payload.gmail_message_id !== 'string' ||
    !payload.gmail_message_id.trim() ||
    payload.gmail_message_id !== payload.gmail_message_id.trim() ||
    !Array.isArray(payload.opportunities) ||
    payload.opportunities.length === 0
  ) {
    throw new Error('El payload de reprocesamiento no es válido.');
  }
  validateOutgoingPayload_({
    source_email: {
      gmail_message_id: payload.gmail_message_id,
      original_body: 'validación local del payload',
    },
    opportunities: payload.opportunities,
  });
}

function validateReprocessHttpResponse_(status, responseText, gmailMessageId, expectedCount) {
  let data;
  try {
    data = JSON.parse(responseText);
  } catch (_error) {
    throw new Error('El endpoint de reprocesamiento devolvió una respuesta inválida.');
  }

  if (
    status < 200 ||
    status >= 300 ||
    !data ||
    data.ok !== true ||
    data.reprocessed !== true ||
    data.duplicate === true ||
    data.gmail_message_id !== gmailMessageId ||
    data.opportunity_count !== expectedCount
  ) {
    const code = data && typeof data.error_code === 'string'
      ? data.error_code
      : 'http_' + status;
    throw new Error('El backend no confirmó el reprocesamiento esperado (' + code + ').');
  }
  return data;
}

function ingestGmailMessage_(message, onOpportunitiesExtracted) {
  const messageId = message.getId();
  if (!isUdeegSender_(message.getFrom())) {
    throw new Error('El mensaje no fue enviado por udeeg_convocatorias@unsa.edu.pe.');
  }
  if (isLocallyProcessed_(messageId)) {
    return { skipped: true, reason: 'already_processed_locally' };
  }

  const originalBody = message.getPlainBody();
  if (typeof originalBody !== 'string' || !originalBody.trim()) {
    throw new Error('El correo no contiene un cuerpo de texto legible.');
  }

  const opportunities = extractOpportunities_(originalBody);
  if (typeof onOpportunitiesExtracted === 'function') {
    onOpportunitiesExtracted(opportunities.length);
  }
  if (opportunities.length === 0) {
    throw new Error('No se encontraron marcadores de convocatoria reconocidos.');
  }

  const sender = extractSenderEmail_(message.getFrom());
  const receivedAt = message.getDate();
  const payload = {
    source_email: {
      gmail_message_id: messageId,
      sender_email: sender,
      subject: message.getSubject() || null,
      received_at: receivedAt ? receivedAt.toISOString() : null,
      original_body: originalBody,
    },
    opportunities: opportunities,
  };

  validateOutgoingPayload_(payload);
  const response = postToSupabase_(payload);
  const result = parseIngestResponse_(response);

  // Save local state only after the backend confirms success. Supabase remains
  // the source of truth and also deduplicates by gmail_message_id.
  PropertiesService.getScriptProperties().setProperty(
    processedPropertyKey_(messageId),
    new Date().toISOString(),
  );
  return result;
}

function postToSupabase_(payload) {
  const properties = PropertiesService.getScriptProperties();
  const functionUrl = properties.getProperty('SUPABASE_FUNCTION_URL');
  const sharedSecret = properties.getProperty('INGEST_SHARED_SECRET');
  if (!functionUrl || !sharedSecret) {
    throw new Error(
      'Configura SUPABASE_FUNCTION_URL e INGEST_SHARED_SECRET en Script Properties.',
    );
  }

  return UrlFetchApp.fetch(functionUrl, {
    method: 'post',
    contentType: 'application/json',
    headers: { 'x-matchunsa-ingest-secret': sharedSecret },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true,
  });
}

function parseIngestResponse_(response) {
  const status = response.getResponseCode();
  let body;
  try {
    body = JSON.parse(response.getContentText());
  } catch (_error) {
    throw new Error('Supabase devolvió una respuesta que no es JSON válido (HTTP ' + status + ').');
  }
  if (status < 200 || status >= 300 || !body || body.ok !== true) {
    const code = body && typeof body.error_code === 'string'
      ? body.error_code
      : 'http_' + status;
    throw new Error('Supabase no confirmó el procesamiento (' + code + ').');
  }
  return body;
}

function extractOpportunities_(emailBody) {
  const markerPattern = /^[^A-Za-zÀ-ÖØ-öø-ÿ]*CONVOCATORIA(?:[ \t]*\r?\n[ \t]*|[ \t]+)(LABORAL|PR[ÁA]CTICAS)\b[ \t]*[-–—−‐‑:]?[ \t]*(.*?)\s*\*?[ \t]*$/gim;
  const markers = [];
  let match;
  while ((match = markerPattern.exec(emailBody)) !== null) {
    let titleSuffix = (match[2] || '').trim();
    if (!titleSuffix) {
      const followingLine = emailBody.slice(markerPattern.lastIndex)
        .split(/\r?\n/)
        .find((line) => line.trim());
      const followingTitle = cleanParserLine_(followingLine || '')
        .replace(/^\d+[.)]\s*/, '')
        .replace(/^[^A-Za-zÀ-ÖØ-öø-ÿ0-9]+/, '')
        .trim();
      if (
        followingTitle &&
        !parseSectionHeader_(followingTitle) &&
        /^[A-ZÁÉÍÓÚÜÑ0-9][A-ZÁÉÍÓÚÜÑ0-9 .,&/()'-]{1,99}$/.test(followingTitle)
      ) {
        titleSuffix = followingTitle;
      }
    }
    markers.push({
      index: match.index,
      end: markerPattern.lastIndex,
      titleSuffix: titleSuffix,
    });
    // Guard against a zero-length match if the pattern is changed later.
    if (match[0].length === 0) markerPattern.lastIndex++;
  }

  return markers.map((marker, index) => {
    const end = index + 1 < markers.length ? markers[index + 1].index : emailBody.length;
    const content = emailBody.slice(marker.index, end).trim();
    return parseOpportunityBlock_(content, marker.titleSuffix);
  });
}

const SECTION_DEFINITIONS = [
  { field: 'title', labels: ['puesto', 'cargo', 'nombre del puesto', 'nombre de la convocatoria', 'puesto o convocatoria'] },
  { field: 'company', labels: ['empresa', 'entidad', 'institucion solicitante'] },
  { field: 'careers', labels: ['formacion profesional', 'formacion profesional solicitada', 'carreras solicitadas', 'carreras requeridas', 'carrera profesional', 'especialidad solicitada'] },
  { field: 'academic_profile', labels: ['perfil', 'perfil academico', 'perfil academico requerido', 'perfil solicitado', 'perfil requerido', 'situacion academica', 'nivel academico'] },
  { field: 'location', labels: ['lugar', 'ubicacion', 'sede', 'zona de trabajo'] },
  { field: 'closing_date', labels: ['cierra', 'fecha de cierre', 'fecha limite', 'cierre de convocatoria', 'fecha de vencimiento', 'plazo de postulacion'] },
  { field: 'vacancies', labels: ['numero de vacantes', 'vacantes', 'cantidad de vacantes'] },
  { field: 'requirements', labels: ['requisitos', 'requerimientos'] },
  { field: 'desired_knowledge', labels: ['conocimientos deseables', 'conocimientos', 'conocimientos requeridos'] },
  { field: 'functions', labels: ['funciones', 'principales funciones', 'actividades a realizar'] },
  { field: 'additional_information', labels: ['informacion adicional', 'observaciones', 'otros datos'] },
  { field: 'application_url', labels: ['postula', 'enlace de postulacion', 'link de postulacion', 'enlace para postular', 'link para postular', 'postulacion', 'como postular', 'postula aqui'] },
  { field: 'application_email', labels: ['correo de postulacion', 'correo para postular', 'correo para enviar cv', 'enviar cv a', 'correo de contacto para postulacion', 'email de postulacion'] },
  { field: 'application_phone', labels: ['telefono de postulacion', 'telefono para postular', 'celular de postulacion', 'whatsapp de postulacion', 'telefono de contacto para postulacion'] },
  { field: 'cv_type', labels: ['cv', 'cv simple', 'tipo de cv', 'cv solicitado', 'curriculum solicitado'] },
];

const LABEL_TO_SECTION = buildLabelMap_();

function buildLabelMap_() {
  const map = {};
  SECTION_DEFINITIONS.forEach((definition) => {
    definition.labels.forEach((label) => {
      map[normalizeLabel_(label)] = definition.field;
    });
  });
  return map;
}

function parseOpportunityBlock_(content, titleSuffix) {
  const fields = {};
  const lines = content.split(/\r?\n/);
  const lineEntries = [];
  for (let index = 0; index < lines.length; index++) {
    const line = lines[index];
    const parsedHeader = parseSectionHeader_(line);
    if ((!parsedHeader || !parsedHeader.value) && index + 1 < lines.length) {
      const splitLabel = normalizeLabel_(
        cleanParserLine_(line) + ' ' + cleanParserLine_(lines[index + 1]),
      );
      const splitField = LABEL_TO_SECTION[splitLabel];
      if (splitField) {
        lineEntries.push({
          raw: line + '\n' + lines[index + 1],
          cleaned: cleanParserLine_(line) + ' ' + cleanParserLine_(lines[index + 1]),
          value: '',
          field: splitField,
        });
        index++;
        continue;
      }
    }
    const cleaned = cleanParserLine_(line);
    lineEntries.push({
      raw: line,
      cleaned: cleaned,
      value: parsedHeader ? parsedHeader.value : '',
      field: parsedHeader ? parsedHeader.field : null,
    });
  }

  let currentField = null;
  lineEntries.forEach((entry) => {
    const signatureText = entry.raw.replace(/^\s*[-•*▪◦]+\s*/, '').trim();
    if (/^(atentamente|cordialmente|saludos(?: cordiales)?|atte\.?)(?:\b|[,.:])/i.test(signatureText)) {
      currentField = null;
      return;
    }
    if (entry.field) {
      currentField = entry.field;
      if (entry.value) appendFieldLine_(fields, currentField, entry.value);
    } else if (currentField && entry.cleaned) {
      appendFieldLine_(
        fields,
        currentField,
        entry.cleaned.replace(/^\s*(?:[-•*▪◦]+|\d+[.)])\s*/, ''),
      );
    } else if (entry.cleaned) {
      currentField = null;
    }
  });

  const opportunity = {
    title: cleanTitle_(firstText_(fields.title) || titleSuffix) || null,
    company: firstText_(fields.company) || null,
    academic_profile: firstText_(fields.academic_profile) || null,
    location: firstText_(fields.location) || null,
    closing_date: parseClosingDate_(fields.closing_date),
    vacancies: parseVacancies_(fields.vacancies),
    requirements: fields.requirements || null,
    desired_knowledge: fields.desired_knowledge || null,
    functions: fields.functions || null,
    additional_information: fields.additional_information || null,
    application_url: extractExplicitUrl_(fields.application_url),
    application_email: extractExplicitEmail_(fields.application_email),
    application_phone: extractExplicitPhone_(fields.application_phone),
    cv_type: firstText_(fields.cv_type) || extractCvTypeFromPostulation_(fields.application_url),
    original_content: content,
    careers: parseCareers_(fields.careers),
  };

  return opportunity;
}

function parseSectionHeader_(line) {
  const cleaned = cleanParserLine_(line);
  if (!cleaned) return null;

  const colonMatch = /^(.{1,100}?)\s*[:：]\s*(.*)$/.exec(cleaned);
  if (colonMatch) {
    const field = LABEL_TO_SECTION[normalizeLabel_(colonMatch[1])];
    if (field) return { field: field, value: cleanParserLine_(colonMatch[2]) };
  }

  const normalized = normalizeLabel_(cleaned);
  if (normalized === 'cv simple') return { field: 'cv_type', value: 'SIMPLE' };
  if (!/[.!?]$/.test(cleaned) && LABEL_TO_SECTION[normalized]) {
    return { field: LABEL_TO_SECTION[normalized], value: '' };
  }

  // These compact labels also occur with a value separated only by whitespace.
  const compactMatch = /^(perfil|cierra|postula|cv)\b\s*(.*)$/i.exec(cleaned);
  if (compactMatch) {
    const field = LABEL_TO_SECTION[normalizeLabel_(compactMatch[1])];
    const value = cleanParserLine_(compactMatch[2]);
    if (field && value) return { field: field, value: value };
  }
  return null;
}

function cleanParserLine_(line) {
  return String(line)
    .replace(/^\s*[-•*▪◦]+\s*/, '')
    .replace(/^\s*[*_~#]+\s*/, '')
    .replace(/\s*[*_~#]+\s*$/, '')
    .trim();
}

function cleanTitle_(title) {
  if (!title) return null;
  return String(title)
    .replace(/\[\s*([^\]]+)\s*\]\(\s*https?:\/\/[^)]+\)/gi, '$1')
    .replace(/<\s*https?:\/\/[^>]*>/gi, '')
    .replace(/https?:\/\/\S+/gi, '')
    .replace(/<[^>]*>/g, '')
    .replace(/\bDEVELOPER\s*\.?\s*NET\b/gi, 'DEVELOPER .NET')
    .replace(/\s+/g, ' ')
    .replace(/^[\s*_~#]+|[\s*_~#]+$/g, '')
    .trim() || null;
}

function extractCvTypeFromPostulation_(postulationText) {
  if (!postulationText) return null;
  const match = /(?:\bCV\s+|\|\s*)(SIMPLE)\b/i.exec(postulationText);
  return match ? match[1].toUpperCase() : null;
}

function isSectionContinuation_(entry) {
  return /^\s+\S/.test(entry.raw) ||
    /^\s*(?:[-•*▪◦]+|\d+[.)])\s+\S/.test(entry.raw);
}

function appendFieldLine_(fields, field, value) {
  fields[field] = fields[field] ? fields[field] + '\n' + value : value;
}

function normalizeLabel_(text) {
  return text.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

function firstText_(value) {
  if (!value) return null;
  return value.split('\n').map((line) => line.trim()).filter(Boolean).join('\n') || null;
}

function parseCareers_(value) {
  if (!value) return null;
  const careers = value.split(/\n|;|,(?![^()]*\))/)
    .map((career) => career.replace(/^\s*[-•*▪◦]+\s*/, '').trim())
    .filter(Boolean);
  return careers.length ? careers : null;
}

function parseClosingDate_(value) {
  if (!value) return null;
  const text = value.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  let match = /(?:^|\D)(\d{4})-(\d{2})-(\d{2})(?!\d)/.exec(text);
  if (match) return validDateString_(Number(match[1]), Number(match[2]), Number(match[3]));

  const months = {
    enero: 1, febrero: 2, marzo: 3, abril: 4, mayo: 5, junio: 6,
    julio: 7, agosto: 8, septiembre: 9, setiembre: 9, octubre: 10,
    noviembre: 11, diciembre: 12,
    ene: 1, feb: 2, mar: 3, abr: 4, may: 5, jun: 6, jul: 7,
    ago: 8, sep: 9, set: 9, oct: 10, nov: 11, dic: 12,
  };
  match = /(?:^|\D)(\d{1,2})\s+(?:de\s+)?([a-z]+)\.?\s+(?:de\s+|del\s+)?(\d{4})(?!\d)/i.exec(text);
  if (match) {
    const monthName = match[2];
    return validDateString_(Number(match[3]), months[monthName], Number(match[1]));
  }

  // The required numeric formats are interpreted strictly as day/month/year.
  match = /(?:^|\D)(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?!\d)/.exec(text);
  if (match) {
    const first = Number(match[1]);
    const second = Number(match[2]);
    return validDateString_(Number(match[3]), second, first);
  }
  return null;
}

function validDateString_(year, month, day) {
  if (year < 1 || year > 9999 || !month || month < 1 || month > 12 || day < 1 || day > 31) return null;
  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  date.setUTCHours(0, 0, 0, 0);
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return String(year).padStart(4, '0') + '-' + String(month).padStart(2, '0') + '-' + String(day).padStart(2, '0');
}

function parseVacancies_(value) {
  if (!value) return null;
  const match = /^\s*(\d+)\s*(?:vacantes?)?\s*$/i.exec(value);
  if (!match) return null;
  const count = Number(match[1]);
  return Number.isSafeInteger(count) && count > 0 && count <= 2147483647 ? count : null;
}

function extractExplicitUrl_(value) {
  if (!value) return null;
  const match = /https?:\/\/[^\s<>"']+/i.exec(value);
  return match ? match[0].replace(/[),.;]+$/, '') : null;
}

function extractExplicitEmail_(value) {
  if (!value) return null;
  const match = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.exec(value);
  return match ? match[0] : null;
}

function extractExplicitPhone_(value) {
  if (!value) return null;
  const match = /(?:\+?\d[\d\s().-]{6,}\d)/.exec(value);
  return match ? match[0].trim() : null;
}

function extractSenderEmail_(fromHeader) {
  if (typeof fromHeader !== 'string') return null;
  const match = /<\s*([^<>\s]+@[^<>\s]+)\s*>/.exec(fromHeader) ||
    /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i.exec(fromHeader);
  return match ? match[1] || match[0] : null;
}

function isUdeegSender_(fromHeader) {
  const sender = extractSenderEmail_(fromHeader);
  return typeof sender === 'string' &&
    sender.trim().toLowerCase() === 'udeeg_convocatorias@unsa.edu.pe';
}

function validateOutgoingPayload_(payload) {
  if (!payload.source_email.gmail_message_id || !payload.source_email.original_body.trim()) {
    throw new Error('El payload no cumple los campos obligatorios de source_email.');
  }
  payload.opportunities.forEach((opportunity, index) => {
    if (!opportunity.original_content || !opportunity.original_content.trim()) {
      throw new Error('La convocatoria ' + (index + 1) + ' no contiene original_content.');
    }
    if (opportunity.closing_date && !/^\d{4}-\d{2}-\d{2}$/.test(opportunity.closing_date)) {
      throw new Error('La fecha de cierre de la convocatoria ' + (index + 1) + ' no es válida.');
    }
    if (opportunity.vacancies !== null && (!Number.isInteger(opportunity.vacancies) || opportunity.vacancies < 1 || opportunity.vacancies > 2147483647)) {
      throw new Error('El número de vacantes de la convocatoria ' + (index + 1) + ' no es válido.');
    }
    if (opportunity.careers !== null && (!Array.isArray(opportunity.careers) || opportunity.careers.some((career) => typeof career !== 'string' || !career.trim()))) {
      throw new Error('Las carreras de la convocatoria ' + (index + 1) + ' no son válidas.');
    }
  });
}

function processedPropertyKey_(gmailMessageId) {
  return MATCHUNSA_LOCAL_PROCESSED_PREFIX + gmailMessageId;
}

function isLocallyProcessed_(gmailMessageId) {
  return Boolean(PropertiesService.getScriptProperties().getProperty(processedPropertyKey_(gmailMessageId)));
}

/** Pure local tests: no Gmail, PropertiesService, Logger, or network calls. */
function runLocalParserTests() {
  const sectionBlock = [
    'CONVOCATORIA LABORAL',
    'Puesto: Analista',
    'Requisitos:',
    '- Manejo de datos',
    'Línea no clasificada',
    'Funciones:',
    '- Elaborar reportes',
    'Atentamente,',
    'Firma institucional',
    'contacto@unsa.edu.pe',
  ].join('\n');
  const parsedSection = parseOpportunityBlock_(sectionBlock, '');
  const multiple = extractOpportunities_(
    'CONVOCATORIA LABORAL\nPuesto: Analista\n' +
    'CONVOCATORIA PRÁCTICAS\nPuesto: Practicante',
  );
  const osmiozMarkers = [
    '*📢 1. CONVOCATORIA  LABORAL – DEVELOPER.NET*',
    '* 📢 2. CONVOCATORIA  LABORAL - ANALISTA DE SOPORTE DE BD*',
    '*📢 3. CONVOCATORIA PRÁCTICAS – ASISTENTE*',
    '*📢 4. CONVOCATORIA PRACTICAS - PRACTICANTE*',
  ].map((marker) => marker + '\nRequisitos:\n- Requisito de prueba').join('\n');
  const osmiozOpportunities = extractOpportunities_(osmiozMarkers);
  const osmiozSummaryAndFullBlocks = [
    'RESUMEN DE OPORTUNIDADES',
    '1. DEVELOPER.NET',
    '2. ANALISTA DE SOPORTE DE BD',
    '3. ASISTENTE DE PROYECTOS TI',
    '4. ANALISTA DE SOPORTE TI',
    '📢 1. CONVOCATORIA LABORAL - DEVELOPER.NET',
    'REQUISITOS:',
    '📢 2. CONVOCATORIA LABORAL - ANALISTA DE SOPORTE DE BD',
    'REQUISITOS:',
    '📢 3. CONVOCATORIA LABORAL - ASISTENTE DE PROYECTOS TI',
    'REQUISITOS:',
    '📢 4. CONVOCATORIA LABORAL - ANALISTA DE SOPORTE TI',
    'REQUISITOS:',
  ].join('\n');
  const osmiozSummaryAndFullOpportunities = extractOpportunities_(osmiozSummaryAndFullBlocks);
  const osmiozParserRegressionBody = [
    'RESUMEN DE OPORTUNIDADES',
    '1. DEVELOPER .NET',
    '2. ANALISTA DE SOPORTE DE BD',
    '3. ASISTENTE DE PROYECTOS TI',
    '4. ANALISTA DE SOPORTE TI',
    '📢 1. CONVOCATORIA LABORAL - DEVELOPER.NET',
    'REQUISITOS',
    'Requisito de prueba 1',
    '📧 POSTULA: | SIMPLE',
    '📢 2. CONVOCATORIA LABORAL - ANALISTA DE SOPORTE DE BD',
    'REQUISITOS',
    'Requisito de prueba 2',
    '📧 POSTULA: | SIMPLE',
    '📢 3. CONVOCATORIA LABORAL - ASISTENTE DE PROYECTOS TI',
    'REQUISITOS',
    'Requisito inicial de prueba 3',
    '- puesto.',
    'Requisito final de prueba 3',
    'Conocimientos',
    'deseables',
    'Conocimiento deseable de prueba 3',
    '📧 POSTULA: | SIMPLE',
    '📢 4. CONVOCATORIA LABORAL - ANALISTA DE SOPORTE TI',
    'REQUISITOS',
    'Requisito inicial de prueba 4',
    '- puesto.',
    'Requisito final de prueba 4',
    'Conocimientos',
    'deseables',
    'Conocimiento deseable de prueba 4',
    '📧 POSTULA: | SIMPLE',
  ].join('\n');
  const osmiozParserRegressionOpportunities = extractOpportunities_(osmiozParserRegressionBody);
  const mixedMarkerTitleLines = extractOpportunities_([
    '📢 1. CONVOCATORIA LABORAL - ANALISTA DE PRUEBA',
    '📢 2. CONVOCATORIA PRÁCTICAS',
    'PRACTICANTE DE PRUEBA',
  ].join('\n'));
  const osmiozFieldFragment = [
    '*📢 1. CONVOCATORIA LABORAL – DEVELOPER.NET <http://DEVELOPER.NET>*',
    '📚 FORMACIÓN PROFESIONAL:',
    'Carrera de prueba',
    '🎓 PERFIL: BACHILLER',
    '🏢 EMPRESA: OSMIOZ',
    '📍 LUGAR: CALLAO',
    '📅 CIERRA: 29/01/2027',
    '👥 VACANTES: 3',
    'REQUISITOS',
    'Fragmento de prueba de requisitos',
    'Conocimientos deseables',
    'Fragmento de prueba de conocimientos',
    'FUNCIONES',
    'Fragmento de prueba de funciones',
    'Información adicional',
    'Fragmento de prueba de información adicional',
    '📧 POSTULA: <https://forms.cloud.microsoft/r/test-form-id> | CV SIMPLE*',
    'Atentamente,',
    'Firma UDEEG',
    'udeeg_convocatorias@unsa.edu.pe',
    '+51 000 000 000',
  ].join('\r\n');
  const osmiozFieldResults = extractOpportunities_(osmiozFieldFragment);
  const osmiozFieldOpportunity = osmiozFieldResults[0];
  const splitHeadingOpportunity = parseOpportunityBlock_(
    'Conocimientos\n  deseables\nTexto de prueba\nFUNCIONES\nTexto de funciones',
    '',
  );
  const payload = {
    source_email: {
      gmail_message_id: 'local-test-id',
      sender_email: 'udeeg_convocatorias@unsa.edu.pe',
      subject: 'Prueba',
      received_at: '2026-10-31T12:00:00.000Z',
      original_body: sectionBlock,
    },
    opportunities: [parsedSection],
  };

  const tests = [
    ['ISO date', () => assertEqual_('ISO date', parseClosingDate_('Cierre: 2026-11-30'), '2026-11-30')],
    ['slash date', () => assertEqual_('slash date', parseClosingDate_('30/11/2026'), '2026-11-30')],
    ['dash date', () => assertEqual_('dash date', parseClosingDate_('30-11-2026'), '2026-11-30')],
    ['Spanish date', () => assertEqual_('Spanish date', parseClosingDate_('15 de noviembre de 2026'), '2026-11-15')],
    ['Spanish abbreviated date', () => assertEqual_('Spanish abbreviated date', parseClosingDate_('15 nov. 2026'), '2026-11-15')],
    ['invalid calendar date', () => assertEqual_('invalid calendar date', parseClosingDate_('29/02/2025'), null)],
    ['ambiguous free-form date', () => assertEqual_('ambiguous free-form date', parseClosingDate_('11 noviembre'), null)],
    ['exact UDEEG sender', () => assertEqual_(
      'exact UDEEG sender',
      isUdeegSender_('UDEEG Convocatorias <udeeg_convocatorias@unsa.edu.pe>'),
      true,
    )],
    ['different sender rejected', () => assertEqual_(
      'different sender rejected',
      isUdeegSender_('UDEEG <not-udeeg@unsa.edu.pe>'),
      false,
    )],
    ['requirements stay separate from functions', () => assertEqual_('requirements stay separate from functions', parsedSection.requirements, 'Manejo de datos\nLínea no clasificada')],
    ['functions isolated', () => assertEqual_('functions isolated', parsedSection.functions, 'Elaborar reportes')],
    ['signature email excluded', () => assertEqual_('signature email excluded', parsedSection.application_email, null)],
    ['full content retained', () => assertEqual_('full content retained', parsedSection.original_content, sectionBlock)],
    ['convocation markers split', () => assertEqual_('convocation markers split', multiple.length, 2)],
    ['OSMIOZ markers detect four convocatorias', () => assertEqual_('OSMIOZ markers detect four convocatorias', osmiozOpportunities.length, 4)],
    ['OSMIOZ summary and complete blocks preserve all four titles', () => assertEqual_(
      'OSMIOZ summary and complete blocks preserve all four titles',
      osmiozSummaryAndFullOpportunities.map((opportunity) => opportunity.title),
      [
        'DEVELOPER .NET',
        'ANALISTA DE SOPORTE DE BD',
        'ASISTENTE DE PROYECTOS TI',
        'ANALISTA DE SOPORTE TI',
      ],
    )],
    ['OSMIOZ real same-line headers detect exactly four opportunities and titles', () => {
      assertEqual_('OSMIOZ opportunity count', osmiozParserRegressionOpportunities.length, 4);
      assertEqual_('OSMIOZ opportunity titles', osmiozParserRegressionOpportunities.map((opportunity) => opportunity.title), [
        'DEVELOPER .NET',
        'ANALISTA DE SOPORTE DE BD',
        'ASISTENTE DE PROYECTOS TI',
        'ANALISTA DE SOPORTE TI',
      ]);
    }],
    ['all four OSMIOZ opportunities extract SIMPLE from pipe notation', () => assertEqual_(
      'all four OSMIOZ opportunities extract SIMPLE from pipe notation',
      osmiozParserRegressionOpportunities.map((opportunity) => opportunity.cv_type),
      ['SIMPLE', 'SIMPLE', 'SIMPLE', 'SIMPLE'],
    )],
    ['OSMIOZ third and fourth requirements retain text around puesto.', () => {
      assertEqual_(
        'OSMIOZ opportunity 3 requirements',
        osmiozParserRegressionOpportunities[2].requirements,
        'Requisito inicial de prueba 3\npuesto.\nRequisito final de prueba 3',
      );
      assertEqual_(
        'OSMIOZ opportunity 4 requirements',
        osmiozParserRegressionOpportunities[3].requirements,
        'Requisito inicial de prueba 4\npuesto.\nRequisito final de prueba 4',
      );
      assertEqual_(
        'OSMIOZ split desired knowledge heading',
        osmiozParserRegressionOpportunities[2].desired_knowledge,
        'Conocimiento deseable de prueba 3',
      );
    }],
    ['labor and practice markers support titles on the same or following line', () => {
      assertEqual_('mixed marker count', mixedMarkerTitleLines.length, 2);
      assertEqual_('mixed marker titles', mixedMarkerTitleLines.map((opportunity) => opportunity.title), [
        'ANALISTA DE PRUEBA',
        'PRACTICANTE DE PRUEBA',
      ]);
    }],
    ['OSMIOZ titles are not split at internal periods', () => assertEqual_(
      'OSMIOZ titles are not split at internal periods',
      osmiozOpportunities[0].title,
      'DEVELOPER .NET',
    )],
    ['OSMIOZ complete convocatorias are separated', () => assertEqual_(
      'OSMIOZ complete convocatorias are separated',
      osmiozOpportunities.every((opportunity) => opportunity.original_content.includes('Requisito de prueba')),
      true,
    )],
    ['OSMIOZ title link annotation removed', () => assertEqual_(
      'OSMIOZ title link annotation removed',
      osmiozFieldOpportunity.title,
      'DEVELOPER .NET',
    )],
    ['OSMIOZ academic profile extracted', () => assertEqual_(
      'OSMIOZ academic profile extracted',
      osmiozFieldOpportunity.academic_profile,
      'BACHILLER',
    )],
    ['OSMIOZ careers extracted', () => assertEqual_(
      'OSMIOZ careers extracted',
      osmiozFieldOpportunity.careers,
      ['Carrera de prueba'],
    )],
    ['OSMIOZ company extracted', () => assertEqual_(
      'OSMIOZ company extracted',
      osmiozFieldOpportunity.company,
      'OSMIOZ',
    )],
    ['OSMIOZ location extracted', () => assertEqual_(
      'OSMIOZ location extracted',
      osmiozFieldOpportunity.location,
      'CALLAO',
    )],
    ['OSMIOZ vacancies extracted', () => assertEqual_(
      'OSMIOZ vacancies extracted',
      osmiozFieldOpportunity.vacancies,
      3,
    )],
    ['OSMIOZ closing date converted', () => assertEqual_(
      'OSMIOZ closing date converted',
      osmiozFieldOpportunity.closing_date,
      '2027-01-29',
    )],
    ['OSMIOZ requirements isolated', () => assertEqual_(
      'OSMIOZ requirements isolated',
      osmiozFieldOpportunity.requirements,
      'Fragmento de prueba de requisitos',
    )],
    ['OSMIOZ desired knowledge isolated', () => assertEqual_(
      'OSMIOZ desired knowledge isolated',
      osmiozFieldOpportunity.desired_knowledge,
      'Fragmento de prueba de conocimientos',
    )],
    ['OSMIOZ functions isolated', () => assertEqual_(
      'OSMIOZ functions isolated',
      osmiozFieldOpportunity.functions,
      'Fragmento de prueba de funciones',
    )],
    ['OSMIOZ application URL follows POSTULA', () => assertEqual_(
      'OSMIOZ application URL follows POSTULA',
      osmiozFieldOpportunity.application_url,
      'https://forms.cloud.microsoft/r/test-form-id',
    )],
    ['OSMIOZ CV type extracted', () => assertEqual_(
      'OSMIOZ CV type extracted',
      osmiozFieldOpportunity.cv_type,
      'SIMPLE',
    )],
    ['OSMIOZ additional information stays in its section', () => assertEqual_(
      'OSMIOZ additional information stays in its section',
      osmiozFieldOpportunity.additional_information,
      'Fragmento de prueba de información adicional',
    )],
    ['wrapped section heading recognized', () => assertEqual_(
      'wrapped section heading recognized',
      splitHeadingOpportunity.desired_knowledge,
      'Texto de prueba',
    )],
    ['OSMIOZ signature contacts are not postulation contacts', () => {
      assertEqual_('OSMIOZ signature application email', osmiozFieldOpportunity.application_email, null);
      assertEqual_('OSMIOZ signature application phone', osmiozFieldOpportunity.application_phone, null);
    }],
    ['first title', () => assertEqual_('first title', multiple[0].title, 'Analista')],
    ['second title', () => assertEqual_('second title', multiple[1].title, 'Practicante')],
    ['source_email field names', () => assertEqual_(
      'source_email field names',
      Object.keys(payload.source_email).sort(),
      ['gmail_message_id', 'original_body', 'received_at', 'sender_email', 'subject'].sort(),
    )],
    ['opportunity field names', () => assertEqual_(
      'opportunity field names',
      Object.keys(parsedSection).sort(),
      [
        'title', 'company', 'academic_profile', 'location', 'closing_date',
        'vacancies', 'requirements', 'desired_knowledge', 'functions',
        'additional_information', 'application_url', 'application_email',
        'application_phone', 'cv_type', 'original_content', 'careers',
      ].sort(),
    )],
    ['payload types and constraints', () => validateOutgoingPayload_(payload)],
  ];

  let passed = 0;
  tests.forEach(([name, run]) => {
    try {
      run();
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      throw new Error('Prueba "' + name + '" falló: ' + reason);
    }
    passed++;
    const message = 'APROBADA: ' + name;
    console.log(message);
    Logger.log(message);
  });

  const summary = 'Resumen: ' + passed + ' de ' + tests.length + ' pruebas aprobadas.';
  console.log(summary);
  Logger.log(summary);
  return summary;
}

/** Pure local tests for the manual reprocess payload and response contract. */
function runLocalReprocessTests() {
  const opportunities = [parseOpportunityBlock_('Convocatoria local de prueba', '')];
  const payload = buildReprocessPayload_('gmail-exact-id', opportunities);
  validateReprocessOutgoingPayload_(payload);

  const successBody = JSON.stringify({
    ok: true,
    reprocessed: true,
    gmail_message_id: 'gmail-exact-id',
    opportunity_count: 1,
  });
  const tests = [
    ['payload uses exact ID and opportunities', () => assertEqual_(
      'payload uses exact ID and opportunities',
      payload,
      { gmail_message_id: 'gmail-exact-id', opportunities: opportunities },
    )],
    ['successful response requires exact ID and count', () => assertEqual_(
      'successful response requires exact ID and count',
      validateReprocessHttpResponse_(200, successBody, 'gmail-exact-id', 1).reprocessed,
      true,
    )],
    ['backend error is rejected', () => assertThrows_(
      'backend error is rejected',
      () => validateReprocessHttpResponse_(
        409,
        JSON.stringify({ ok: false, error_code: 'source_email_not_processed' }),
        'gmail-exact-id',
        1,
      ),
    )],
    ['wrong Gmail ID is rejected', () => assertThrows_(
      'wrong Gmail ID is rejected',
      () => validateReprocessHttpResponse_(
        200,
        JSON.stringify({
          ok: true,
          reprocessed: true,
          gmail_message_id: 'other-id',
          opportunity_count: 1,
        }),
        'gmail-exact-id',
        1,
      ),
    )],
    ['unexpected duplicate result is rejected', () => assertThrows_(
      'unexpected duplicate result is rejected',
      () => validateReprocessHttpResponse_(
        200,
        JSON.stringify({
          ok: true,
          duplicate: true,
          reprocessed: false,
          gmail_message_id: 'gmail-exact-id',
          opportunity_count: 1,
        }),
        'gmail-exact-id',
        1,
      ),
    )],
    ['incorrect opportunity count is rejected', () => assertThrows_(
      'incorrect opportunity count is rejected',
      () => validateReprocessHttpResponse_(200, successBody, 'gmail-exact-id', 4),
    )],
    ['invalid response JSON is rejected', () => assertThrows_(
      'invalid response JSON is rejected',
      () => validateReprocessHttpResponse_(200, 'not-json', 'gmail-exact-id', 1),
    )],
  ];

  let passed = 0;
  tests.forEach(([name, run]) => {
    try {
      run();
    } catch (error) {
      const reason = error instanceof Error ? error.message : String(error);
      throw new Error('Prueba "' + name + '" falló: ' + reason);
    }
    passed++;
    const message = 'APROBADA: ' + name;
    console.log(message);
    Logger.log(message);
  });
  const summary = 'Resumen de reprocesamiento: ' + passed + ' de ' + tests.length + ' pruebas aprobadas.';
  console.log(summary);
  Logger.log(summary);
  return summary;
}

function assertThrows_(name, operation) {
  let thrown = false;
  try {
    operation();
  } catch (_error) {
    thrown = true;
  }
  if (!thrown) throw new Error('Se esperaba una excepción en "' + name + '".');
}

function assertEqual_(name, actual, expected) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      'Falló "' + name + '": esperado ' + JSON.stringify(expected) +
      ', recibido ' + JSON.stringify(actual),
    );
  }
}

function ejecutarReprocesamientoOSMIOZ() {
  try {
    const result = reprocesarCorreoUdeegPorId('1a18e9e617d73530');
    Logger.log('Resultado de reprocesamiento OSMIOZ: ' + JSON.stringify(result));
    return result;
  } catch (error) {
    Logger.log(
      'Error en reprocesamiento OSMIOZ: ' +
        (error instanceof Error ? error.message : String(error)),
    );
    throw error;
  }
}
