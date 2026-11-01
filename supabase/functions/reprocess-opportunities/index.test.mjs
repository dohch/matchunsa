import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";
import {
  assertSuccessfulReprocessResult,
  validateReprocessPayload,
} from "../_shared/reprocess_contract.mjs";

const source = readFileSync(new URL("./index.ts", import.meta.url), "utf8");
const jsSource = process.getBuiltinModule("node:module")
  .stripTypeScriptTypes(source)
  .replace(/^import \{ createClient \} from "npm:@supabase\/supabase-js@2";\s*/m, "")
  .replace(
    /^import \{[\s\S]*?\} from "\.\.\/_shared\/reprocess_contract\.mjs";\s*/m,
    "",
  );

function makeHandler(rpcResponse) {
  const calls = [];
  let handler;
  const context = {
    TextEncoder,
    Request,
    Response,
    URL,
    assertSuccessfulReprocessResult,
    validateReprocessPayload,
    createClient: (url, key, options) => {
      calls.push({ client: { url, key, options } });
      return {
        rpc: async (name, args) => {
          calls.push({ rpc: name, args });
          return rpcResponse;
        },
      };
    },
    Deno: {
      env: {
        get(name) {
          return {
            SUPABASE_URL: "https://local-project.invalid",
            SUPABASE_SERVICE_ROLE_KEY: "local-only-service-role-fixture",
            REPROCESS_SHARED_SECRET: "local-only-reprocess-secret",
          }[name];
        },
      },
      serve(callback) {
        handler = callback;
      },
    },
  };
  vm.runInNewContext(jsSource, context);
  return { handler, calls };
}

function makeRequest(body, secret = "local-only-reprocess-secret") {
  return new Request("https://function.local/reprocess-opportunities", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-matchunsa-reprocess-secret": secret,
    },
    body: JSON.stringify(body),
  });
}

const payload = {
  gmail_message_id: "local-gmail-message-id",
  opportunities: [
    { title: "Una oportunidad", original_content: "Contenido original" },
  ],
};

test("rejects an invalid shared secret before creating the service client", async () => {
  const { handler, calls } = makeHandler({ data: null, error: null });
  const response = await handler(makeRequest(payload, "wrong-local-secret"));
  assert.equal(response.status, 401);
  assert.equal(calls.length, 0);
});

test("rejects malformed payloads before invoking the RPC", async () => {
  const { handler, calls } = makeHandler({ data: null, error: null });
  const response = await handler(makeRequest({ ...payload, unexpected: true }));
  assert.equal(response.status, 400);
  assert.equal(calls.filter((call) => call.rpc).length, 0);
});

test("uses only the administrative RPC and confirms the exact ID and count", async () => {
  const { handler, calls } = makeHandler({
    data: {
      ok: true,
      reprocessed: true,
      gmail_message_id: payload.gmail_message_id,
      opportunity_count: 1,
    },
    error: null,
  });
  const response = await handler(makeRequest(payload));
  const json = await response.json();
  assert.equal(response.status, 200);
  assert.equal(json.reprocessed, true);
  const rpcCall = calls.find((call) => call.rpc);
  assert.equal(rpcCall.rpc, "reprocess_opportunities_for_email");
  assert.equal(JSON.stringify(rpcCall.args), JSON.stringify({
    p_gmail_message_id: payload.gmail_message_id,
    p_opportunities: payload.opportunities,
  }));
  assert.equal(calls.filter((call) => call.rpc).length, 1);
});

test("maps RPC refusal without issuing any follow-up write", async () => {
  const { handler, calls } = makeHandler({
    data: { ok: false, error_code: "source_email_not_processed" },
    error: null,
  });
  const response = await handler(makeRequest(payload));
  assert.equal(response.status, 409);
  assert.equal(calls.filter((call) => call.rpc).length, 1);
});

test("returns a generic failure if the transactional RPC errors", async () => {
  const { handler, calls } = makeHandler({
    data: null,
    error: { message: "local simulated database error" },
  });
  const response = await handler(makeRequest(payload));
  const json = await response.json();
  assert.equal(response.status, 500);
  assert.deepEqual(json, { ok: false, error_code: "reprocess_failed" });
  assert.equal(calls.filter((call) => call.rpc).length, 1);
});
