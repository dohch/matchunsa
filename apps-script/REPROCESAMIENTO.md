# Reprocesar un correo UDEEG ya procesado

La ruta de reprocesamiento está separada de processNewUdeegEmails() y de la
función ingest-opportunities. Requiere el Gmail message ID exacto y solo
acepta mensajes cuyo remitente sea udeeg_convocatorias@unsa.edu.pe y cuya fila
en source_emails tenga processing_status = 'processed'.

La RPC bloquea esa fila, usa el mismo reemplazo de oportunidades/carreras de la
ingestión normal y verifica su resultado antes de terminar. Un error o respuesta
inesperada genera una excepción PostgreSQL para revertir el reprocesamiento
completo. La fila y el contenido original de source_emails se conservan.

## Preparación para despliegue

Estos pasos son manuales. Este repositorio no ejecuta la migración ni despliega
la función automáticamente.

1. Revisa y aplica supabase/migrations/20261031170000_reprocess_opportunities.sql
   al proyecto Supabase que ya contiene las migraciones anteriores.
2. En Supabase, configura el secreto Edge Function REPROCESS_SHARED_SECRET
   con un valor aleatorio nuevo, distinto de INGEST_SHARED_SECRET. No lo
   registres en logs ni lo incluyas en el repositorio.
3. Despliega la nueva función:

       supabase functions deploy reprocess-opportunities --project-ref <PROJECT_REF>

   La clave SUPABASE_SERVICE_ROLE_KEY permanece exclusivamente en el entorno
   de Supabase; no se copia a Apps Script.
4. En las Script Properties del proyecto Apps Script agrega:
   - REPROCESS_FUNCTION_URL:
     https://<PROJECT_REF>.supabase.co/functions/v1/reprocess-opportunities
   - REPROCESS_SHARED_SECRET: exactamente el mismo valor configurado en Supabase.

   Conserva sin cambios SUPABASE_FUNCTION_URL e INGEST_SHARED_SECRET, que
   siguen perteneciendo a la ingestión normal.
5. En Apps Script, ejecuta manualmente:

       reprocesarCorreoUdeegPorId('GMAIL_MESSAGE_ID_EXACTO')

   La función valida el remitente, vuelve a extraer las convocatorias y espera
   la confirmación del backend para reportar éxito. No consulta ni cambia el
   marcador local; el procesamiento automático continúa omitiendo ese correo.
6. Confirma en Supabase que el mismo source_emails.id permanece y que solo las
   oportunidades relacionadas con ese mensaje fueron reemplazadas.

No borres el marcador local para este procedimiento. La RPC normal considera
processed un duplicado y no actualiza sus oportunidades.

## Pruebas locales

Las pruebas que no requieren servicios externos:

    node --test apps-script/tests/*.test.mjs
    node --test supabase/functions/_shared/reprocess_contract.test.mjs supabase/functions/reprocess-opportunities/index.test.mjs
    node --check < apps-script/Código.gs

La prueba PostgreSQL de éxito, aislamiento, autorización y rollback está en
supabase/tests/reprocess_opportunities.sql. Ejecútala únicamente contra un
stack Supabase local desechable ya inicializado:

    supabase test db supabase/tests/reprocess_opportunities.sql --local

Ese test usa una transacción que revierte sus datos de fixture. No lo ejecutes
con --linked ni contra producción.
