import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Código.gs", import.meta.url), "utf8");
const messageId = "1a18e9e617d73530";
const processedKey = "MATCHUNSA_PROCESSED_GMAIL_" + messageId;
function makeBody(opportunityCount) {
  return Array.from({ length: opportunityCount }, (_, index) => [
    "*📢 " + (index + 1) + ". CONVOCATORIA LABORAL – OSMIOZ " + (index + 1) + "*",
    "Requisitos:",
    "- Texto de prueba",
  ].join("\n")).join("\n");
}

function createHarness({ sender, responseStatus = 200, responseBody, opportunityCount = 4 }) {
  const properties = {
    REPROCESS_FUNCTION_URL: "https://project.invalid/functions/v1/reprocess-opportunities",
    REPROCESS_SHARED_SECRET: "local-only-admin-secret",
    [processedKey]: "existing-local-marker",
  };
  const writes = [];
  const fetchCalls = [];
  let released = false;
  const context = {
    console: { log() {} },
    Logger: { log() {} },
    LockService: {
      getScriptLock: () => ({
        waitLock() {},
        releaseLock() { released = true; },
      }),
    },
    GmailApp: {
      getMessageById(id) {
        assert.equal(id, messageId);
        return {
          getFrom: () => sender,
          getPlainBody: () => makeBody(opportunityCount),
        };
      },
    },
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: (key) => properties[key] ?? null,
        setProperty: (key, value) => {
          writes.push([key, value]);
          properties[key] = value;
        },
      }),
    },
    UrlFetchApp: {
      fetch(url, options) {
        fetchCalls.push({ url, options });
        return {
          getResponseCode: () => responseStatus,
          getContentText: () => responseBody,
        };
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(source, context);
  return {
    call: () => vm.runInContext(
      "reprocesarCorreoUdeegPorId(" + JSON.stringify(messageId) + ")",
      context,
    ),
    fetchCalls,
    properties,
    writes,
    wasReleased: () => released,
  };
}

test("manual reprocess posts exact ID and leaves local processed marker untouched", () => {
  const responseBody = JSON.stringify({
    ok: true,
    reprocessed: true,
    gmail_message_id: messageId,
    opportunity_count: 4,
  });
  const harness = createHarness({
    sender: "UDEEG <udeeg_convocatorias@unsa.edu.pe>",
    responseBody,
  });

  const result = harness.call();
  assert.equal(result.reprocessed, true);
  assert.equal(harness.fetchCalls.length, 1);
  assert.equal(
    harness.fetchCalls[0].url,
    "https://project.invalid/functions/v1/reprocess-opportunities",
  );
  assert.equal(
    harness.fetchCalls[0].options.headers["x-matchunsa-reprocess-secret"],
    "local-only-admin-secret",
  );
  const requestPayload = JSON.parse(harness.fetchCalls[0].options.payload);
  assert.equal(requestPayload.gmail_message_id, messageId);
  assert.equal(requestPayload.opportunities.length, 4);
  assert.equal(requestPayload.source_email, undefined);
  assert.equal(harness.properties[processedKey], "existing-local-marker");
  assert.equal(harness.writes.length, 0);
  assert.equal(harness.wasReleased(), true);
});

for (const opportunityCount of [3, 5]) {
  test("target email rejects " + opportunityCount + " opportunities before the HTTP request", () => {
    const harness = createHarness({
      sender: "UDEEG <udeeg_convocatorias@unsa.edu.pe>",
      opportunityCount,
      responseBody: "{}",
    });

    assert.throws(
      () => harness.call(),
      new RegExp("exactamente 4 convocatorias; se detectaron " + opportunityCount),
    );
    assert.equal(harness.fetchCalls.length, 0);
    assert.equal(harness.properties[processedKey], "existing-local-marker");
    assert.equal(harness.writes.length, 0);
    assert.equal(harness.wasReleased(), true);
  });
}

test("target email accepts exactly 4 parsed opportunities", () => {
  const harness = createHarness({
    sender: "UDEEG <udeeg_convocatorias@unsa.edu.pe>",
    opportunityCount: 4,
    responseBody: JSON.stringify({
      ok: true,
      reprocessed: true,
      gmail_message_id: messageId,
      opportunity_count: 4,
    }),
  });

  assert.equal(harness.call().reprocessed, true);
  assert.equal(harness.fetchCalls.length, 1);
  assert.equal(JSON.parse(harness.fetchCalls[0].options.payload).opportunities.length, 4);
  assert.equal(harness.properties[processedKey], "existing-local-marker");
  assert.equal(harness.writes.length, 0);
});

test("manual reprocess refuses a different sender before sending", () => {
  const harness = createHarness({
    sender: "other@example.edu",
    responseBody: "{}",
  });
  assert.throws(() => harness.call(), /remitente UDEEG exacto/);
  assert.equal(harness.fetchCalls.length, 0);
  assert.equal(harness.properties[processedKey], "existing-local-marker");
  assert.equal(harness.writes.length, 0);
  assert.equal(harness.wasReleased(), true);
});

test("manual reprocess preserves local marker when the backend rejects the request", () => {
  const harness = createHarness({
    sender: "udeeg_convocatorias@unsa.edu.pe",
    responseStatus: 409,
    responseBody: JSON.stringify({
      ok: false,
      error_code: "source_email_not_processed",
    }),
  });
  assert.throws(() => harness.call(), /no confirmó el reprocesamiento esperado/);
  assert.equal(harness.properties[processedKey], "existing-local-marker");
  assert.equal(harness.writes.length, 0);
  assert.equal(harness.wasReleased(), true);
});
