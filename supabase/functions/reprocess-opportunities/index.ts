import { createClient } from "npm:@supabase/supabase-js@2";
import {
  assertSuccessfulReprocessResult,
  validateReprocessPayload,
} from "../_shared/reprocess_contract.mjs";

const SECRET_HEADER = "x-matchunsa-reprocess-secret";
const encoder = new TextEncoder();

type JsonObject = Record<string, unknown>;

function jsonResponse(status: number, body: JsonObject): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function secretsMatch(expected: string, supplied: string): boolean {
  if (!expected || !supplied) return false;
  const expectedBytes = encoder.encode(expected);
  const suppliedBytes = encoder.encode(supplied);
  let difference = expectedBytes.length ^ suppliedBytes.length;
  const length = Math.max(expectedBytes.length, suppliedBytes.length);
  for (let index = 0; index < length; index++) {
    difference |= (expectedBytes[index] ?? 0) ^ (suppliedBytes[index] ?? 0);
  }
  return difference === 0;
}

function createSupabaseAdmin() {
  const projectUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!projectUrl || !serviceRoleKey) return null;
  return createClient(projectUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return jsonResponse(405, { ok: false, error_code: "method_not_allowed" });
  }

  const expectedSecret = Deno.env.get("REPROCESS_SHARED_SECRET") ?? "";
  if (!expectedSecret) {
    return jsonResponse(500, { ok: false, error_code: "function_not_configured" });
  }
  if (!secretsMatch(expectedSecret, request.headers.get(SECRET_HEADER) ?? "")) {
    return jsonResponse(401, { ok: false, error_code: "unauthorized" });
  }

  if (!request.headers.get("content-type")?.toLowerCase().includes("application/json")) {
    return jsonResponse(400, { ok: false, error_code: "invalid_content_type" });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(400, { ok: false, error_code: "invalid_json" });
  }

  const validation = validateReprocessPayload(body);
  if (!validation.valid) {
    return jsonResponse(400, {
      ok: false,
      error_code: "invalid_payload",
      errors: validation.errors,
    });
  }

  const supabase = createSupabaseAdmin();
  if (!supabase) {
    return jsonResponse(500, { ok: false, error_code: "function_not_configured" });
  }

  try {
    const { data, error } = await supabase.rpc(
      "reprocess_opportunities_for_email",
      {
        p_gmail_message_id: validation.payload.gmail_message_id,
        p_opportunities: validation.payload.opportunities,
      },
    );

    if (error) {
      // Do not expose database details or attempt a second write. PostgreSQL
      // has rolled the RPC transaction back before returning this error.
      return jsonResponse(500, { ok: false, error_code: "reprocess_failed" });
    }

    if (data && typeof data === "object" && !Array.isArray(data) && data.ok !== true) {
      const errorCode = typeof data.error_code === "string" ? data.error_code : "";
      const statusByCode: Record<string, number> = {
        invalid_gmail_message_id: 400,
        invalid_opportunities: 400,
        source_email_not_found: 404,
        source_email_not_udeeg: 403,
        source_email_not_processed: 409,
      };
      return jsonResponse(statusByCode[errorCode] ?? 500, {
        ok: false,
        error_code: statusByCode[errorCode] ? errorCode : "reprocess_failed",
      });
    }

    const result = assertSuccessfulReprocessResult(
      data,
      validation.payload.gmail_message_id,
      validation.payload.opportunities.length,
    );
    return jsonResponse(200, result);
  } catch {
    // An unexpected RPC result is an error. The database function also raises
    // on this condition, so its transaction is rolled back.
    return jsonResponse(500, { ok: false, error_code: "reprocess_failed" });
  }
});
