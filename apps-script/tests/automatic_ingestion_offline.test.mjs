import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Código.gs", import.meta.url), "utf8");
const sender = "udeeg_convocatorias@unsa.edu.pe";
const startProperty = "MATCHUNSA_AUTOMATION_START_MS";
const scanProperty = "MATCHUNSA_LAST_SCAN_MS";
const retryProperty = "MATCHUNSA_RETRY_GMAIL_IDS";

function makeMessage(id, from, date, body = "📢 1. CONVOCATORIA LABORAL - Analista\nRequisitos:\nTexto de prueba") {
  return {
    getId: () => id,
    getFrom: () => from,
    getDate: () => new Date(date),
    getPlainBody: () => body,
    getSubject: () => "Convocatoria de prueba",
  };
}

function createAutomationHarness({ messages, properties: initialProperties = {}, responseForId }) {
  const properties = { ...initialProperties };
  properties.SUPABASE_FUNCTION_URL ??= "https://project.invalid/functions/v1/ingest-opportunities";
  properties.INGEST_SHARED_SECRET ??= "local-ingest-secret";
  const fetchCalls = [];
  const logs = [];
  const triggers = [];
  let searches = 0;
  const messageById = new Map(messages.map((message) => [message.getId(), message]));

  const context = {
    console: { log() {} },
    Logger: { log: (message) => logs.push(String(message)) },
    Date,
    JSON,
    Set,
    Number,
    String,
    RegExp,
    LockService: {
      getScriptLock: () => ({ waitLock() {}, releaseLock() {} }),
    },
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: (key) => properties[key] ?? null,
        setProperty: (key, value) => { properties[key] = String(value); },
        deleteProperty: (key) => { delete properties[key]; },
      }),
    },
    GmailApp: {
      search(query, start, pageSize) {
        assert.match(query, /^from:udeeg_convocatorias@unsa\.edu\.pe after:\d{4}\/\d{2}\/\d{2}$/);
        assert.equal(pageSize, 50);
        searches++;
        return start === 0 ? [{ getMessages: () => messages }] : [];
      },
      getMessageById(id) {
        const message = messageById.get(id);
        if (!message) throw new Error("message not found");
        return message;
      },
    },
    UrlFetchApp: {
      fetch(url, options) {
        const payload = JSON.parse(options.payload);
        const gmailMessageId = payload.source_email.gmail_message_id;
        fetchCalls.push({ url, options, gmailMessageId });
        return responseForId(gmailMessageId, fetchCalls.length);
      },
    },
    ScriptApp: {
      getProjectTriggers: () => [...triggers],
      deleteTrigger: (trigger) => {
        const index = triggers.indexOf(trigger);
        if (index >= 0) triggers.splice(index, 1);
      },
      newTrigger: (handler) => ({
        timeBased: () => ({
          everyMinutes: (minutes) => ({
            create: () => {
              const trigger = {
                handler,
                minutes,
                getHandlerFunction: () => handler,
              };
              triggers.push(trigger);
              return trigger;
            },
          }),
        }),
      }),
    },
    Date,
  };
  vm.createContext(context);
  vm.runInContext(source, context);

  return {
    call: () => vm.runInContext("processNewUdeegEmails()", context),
    configureTrigger: () => vm.runInContext("configurarActivadorUdeegCada5Minutos()", context),
    fetchCalls,
    logs,
    properties,
    searches: () => searches,
    triggers,
  };
}

function backendSuccess(id) {
  return {
    getResponseCode: () => 200,
    getContentText: () => JSON.stringify({
      ok: true,
      duplicate: false,
      gmail_message_id: id,
      opportunity_count: 1,
    }),
  };
}

test("automatic processing handles every new exact UDEEG message and ignores history/other senders", () => {
  const now = Date.now();
  const baseline = now - 5000;
  const messages = [
    makeMessage("new-1", "UDEEG <" + sender + ">", now - 1000),
    makeMessage("new-2", sender, now - 500),
    makeMessage("old", sender, baseline - 1000),
    makeMessage("personal", "personal@example.com", now - 300),
  ];
  const harness = createAutomationHarness({
    messages,
    properties: {
      [startProperty]: String(baseline),
      [scanProperty]: String(baseline),
    },
    responseForId: (id) => backendSuccess(id),
  });

  const results = harness.call();
  assert.equal(results.length, 2);
  assert.equal(harness.fetchCalls.length, 2, harness.logs.join(" | "));
  assert.equal(
    JSON.stringify(harness.fetchCalls.map((call) => call.gmailMessageId)),
    JSON.stringify(["new-1", "new-2"]),
  );
  assert.ok(harness.properties["MATCHUNSA_PROCESSED_GMAIL_new-1"]);
  assert.ok(harness.properties["MATCHUNSA_PROCESSED_GMAIL_new-2"]);
  assert.equal(harness.properties["MATCHUNSA_PROCESSED_GMAIL_old"], undefined);
  assert.equal(harness.properties["MATCHUNSA_PROCESSED_GMAIL_personal"], undefined);
  assert.ok(harness.logs.some((line) => line.includes("encontrados=2, procesados=2")));
  assert.ok(harness.logs.some((line) => line.includes("convocatorias_extraídas=2, errores=0")));
  assert.equal(harness.searches(), 1);
});

test("failed automatic messages remain queued and retry on the next run", () => {
  const now = Date.now();
  const baseline = now - 5000;
  const message = makeMessage("retry-me", sender, now - 500);
  let shouldFail = true;
  const harness = createAutomationHarness({
    messages: [message],
    properties: {
      [startProperty]: String(baseline),
      [scanProperty]: String(baseline),
    },
    responseForId: (id) => {
      if (shouldFail) {
        return {
          getResponseCode: () => 500,
          getContentText: () => JSON.stringify({ ok: false, error_code: "reprocess_failed" }),
        };
      }
      return backendSuccess(id);
    },
  });

  assert.equal(harness.call().length, 1);
  assert.equal(harness.properties["MATCHUNSA_PROCESSED_GMAIL_retry-me"], undefined);
  assert.deepEqual(JSON.parse(harness.properties[retryProperty]), ["retry-me"]);

  shouldFail = false;
  assert.equal(harness.call().length, 1);
  assert.ok(harness.properties["MATCHUNSA_PROCESSED_GMAIL_retry-me"]);
  assert.equal(harness.properties[retryProperty], undefined);
  assert.equal(harness.fetchCalls.length, 2);
});

test("trigger setup replaces duplicates and leaves one five-minute trigger", () => {
  const harness = createAutomationHarness({
    messages: [],
    properties: {},
    responseForId: () => backendSuccess("unused"),
  });
  const oldTrigger = () => ({
    getHandlerFunction: () => "processNewUdeegEmails",
  });
  harness.triggers.push(oldTrigger(), oldTrigger());

  harness.configureTrigger();
  harness.configureTrigger();

  assert.equal(harness.triggers.length, 1);
  assert.equal(harness.triggers[0].handler, "processNewUdeegEmails");
  assert.equal(harness.triggers[0].minutes, 5);
  assert.ok(harness.properties[startProperty]);
  assert.ok(harness.properties[scanProperty]);
});
