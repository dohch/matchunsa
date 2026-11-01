import { createClient } from "npm:@supabase/supabase-js@2";

const SECRET_HEADER = "x-matchunsa-ingest-secret";
const encoder = new TextEncoder();

type JsonObject = Record<string, unknown>;

type SourceEmail = {
  gmail_message_id: string;
  sender_email?: string | null;
  subject?: string | null;
  received_at?: string | null;
  original_body: string;
};

type OpportunityPayload = {
  title?: string | null;
  company?: string | null;
  academic_profile?: string | null;
  location?: string | null;
  closing_date?: string | null;
  vacancies?: number | null;
  requirements?: string | null;
  desired_knowledge?: string | null;
  functions?: string | null;
  additional_information?: string | null;
  application_url?: string | null;
  application_email?: string | null;
  application_phone?: string | null;
  cv_type?: string | null;
  original_content: string;
  careers?: string[] | null;
};

type IngestPayload = {
  source_email: SourceEmail;
  opportunities: OpportunityPayload[];
};

type ValidationResult =
  | { valid: true; payload: IngestPayload }
  | { valid: false; errors: string[]; gmailMessageId?: string };

const sourceEmailKeys = [
  "gmail_message_id",
  "sender_email",
  "subject",
  "received_at",
  "original_body",
] as const;
const requiredSourceEmailKeys = ["gmail_message_id", "original_body"] as const;

const optionalTextFields = [
  "title",
  "company",
  "academic_profile",
  "location",
  "requirements",
  "desired_knowledge",
  "functions",
  "additional_information",
  "application_url",
  "application_email",
  "application_phone",
  "cv_type",
] as const;

const opportunityKeys = new Set<string>([
  ...optionalTextFields,
  "closing_date",
  "vacancies",
  "original_content",
  "careers",
]);

function jsonResponse(status: number, body: JsonObject): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function isRecord(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function secretsMatch(expected: string, supplied: string): boolean {
  if (expected.length === 0 || supplied.length === 0) return false;

  const expectedBytes = encoder.encode(expected);
  const suppliedBytes = encoder.encode(supplied);
  let difference = expectedBytes.length ^ suppliedBytes.length;
  const length = Math.max(expectedBytes.length, suppliedBytes.length);

  for (let index = 0; index < length; index++) {
    difference |= (expectedBytes[index] ?? 0) ^ (suppliedBytes[index] ?? 0);
  }

  return difference === 0;
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

function isValidCalendarDate(year: number, month: number, day: number): boolean {
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return false;

  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  date.setUTCHours(0, 0, 0, 0);
  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

function hasOwn(record: JsonObject, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(record, key);
}

function isIsoTimestamp(value: string): boolean {
  const isoWithTimezone =
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|([+-])(\d{2}):(\d{2}))$/;
  const match = isoWithTimezone.exec(value);
  if (!match) return false;

  const [, year, month, day, hour, minute, second, , zone, , offsetHour, offsetMinute] = match;
  const offsetHours = Number(offsetHour ?? 0);
  const offsetMinutes = Number(offsetMinute ?? 0);
  return isValidCalendarDate(Number(year), Number(month), Number(day)) &&
    Number(hour) <= 23 &&
    Number(minute) <= 59 &&
    Number(second) <= 59 &&
    (zone?.toUpperCase() === "Z" ||
      (offsetHours <= 14 && offsetMinutes <= 59 &&
        (offsetHours < 14 || offsetMinutes === 0)));
}

function isIsoDate(value: string): boolean {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return false;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  return isValidCalendarDate(year, month, day);
}

function getGmailMessageId(payload: unknown): string | undefined {
  if (!isRecord(payload) || !isRecord(payload.source_email)) return undefined;
  const id = payload.source_email.gmail_message_id;
  return typeof id === "string" && id.trim().length > 0 ? id.trim() : undefined;
}

function validatePayload(value: unknown): ValidationResult {
  const errors: string[] = [];

  if (!isRecord(value)) {
    return { valid: false, errors: ["El cuerpo debe ser un objeto JSON."] };
  }

  const allowedRootKeys = new Set(["source_email", "opportunities"]);
  for (const key of Object.keys(value)) {
    if (!allowedRootKeys.has(key)) errors.push("El cuerpo contiene un campo raíz no permitido.");
  }

  const gmailMessageId = getGmailMessageId(value);
  if (!hasOwn(value, "source_email") || !isRecord(value.source_email)) {
    errors.push("source_email debe ser un objeto.");
  }

  if (!hasOwn(value, "opportunities") || !Array.isArray(value.opportunities)) {
    errors.push("opportunities debe ser un arreglo.");
  }

  let sourceEmail: SourceEmail | undefined;
  if (isRecord(value.source_email)) {
    const rawEmail = value.source_email;
    const allowedKeys = new Set<string>(sourceEmailKeys);

    for (const key of Object.keys(rawEmail)) {
      if (!allowedKeys.has(key)) errors.push("source_email contiene un campo no permitido.");
    }

    for (const key of requiredSourceEmailKeys) {
      if (!hasOwn(rawEmail, key)) {
        errors.push(`source_email.${key} es obligatorio.`);
      }
    }

    if (
      typeof rawEmail.gmail_message_id !== "string" ||
      rawEmail.gmail_message_id.trim().length === 0
    ) {
      errors.push("source_email.gmail_message_id debe ser un texto no vacío.");
    }

    for (const key of ["sender_email", "subject"] as const) {
      if (hasOwn(rawEmail, key) && !isNullableString(rawEmail[key])) {
        errors.push(`source_email.${key} debe ser texto o null.`);
      }
    }

    let normalizedReceivedAt = rawEmail.received_at;
    if (typeof normalizedReceivedAt === "string") {
      normalizedReceivedAt = normalizedReceivedAt.trim();
      if (normalizedReceivedAt.length === 0) normalizedReceivedAt = null;
    }
    if (
      hasOwn(rawEmail, "received_at") &&
      normalizedReceivedAt !== null &&
      (typeof normalizedReceivedAt !== "string" ||
        !isIsoTimestamp(normalizedReceivedAt))
    ) {
      errors.push(
        "source_email.received_at debe usar YYYY-MM-DDTHH:mm:ss, fracción opcional de 1 a 6 dígitos y zona Z o ±HH:MM (máximo 14:00), o ser null.",
      );
    }

    if (
      typeof rawEmail.original_body !== "string" ||
      rawEmail.original_body.trim().length === 0
    ) {
      errors.push("source_email.original_body debe ser un texto no vacío.");
    }

    if (
      typeof rawEmail.gmail_message_id === "string" &&
      rawEmail.gmail_message_id.trim().length > 0 &&
      (!hasOwn(rawEmail, "sender_email") || isNullableString(rawEmail.sender_email)) &&
      (!hasOwn(rawEmail, "subject") || isNullableString(rawEmail.subject)) &&
      (!hasOwn(rawEmail, "received_at") || normalizedReceivedAt === null ||
        (typeof normalizedReceivedAt === "string" && isIsoTimestamp(normalizedReceivedAt))) &&
      typeof rawEmail.original_body === "string" &&
      rawEmail.original_body.trim().length > 0
    ) {
      sourceEmail = {
        gmail_message_id: rawEmail.gmail_message_id.trim(),
        original_body: rawEmail.original_body,
      };
      if (hasOwn(rawEmail, "sender_email")) {
        sourceEmail.sender_email = rawEmail.sender_email as string | null;
      }
      if (hasOwn(rawEmail, "subject")) {
        sourceEmail.subject = rawEmail.subject as string | null;
      }
      if (hasOwn(rawEmail, "received_at")) {
        sourceEmail.received_at = normalizedReceivedAt as string | null;
      }
    }
  }

  const opportunities: OpportunityPayload[] = [];
  if (Array.isArray(value.opportunities)) {
    value.opportunities.forEach((item, index) => {
      const prefix = `opportunities[${index}]`;
      if (!isRecord(item)) {
        errors.push(`${prefix} debe ser un objeto.`);
        return;
      }

      for (const key of Object.keys(item)) {
        if (!opportunityKeys.has(key)) {
          errors.push(`${prefix} contiene un campo no permitido.`);
        }
      }

      const opportunity: OpportunityPayload = {
        original_content:
          typeof item.original_content === "string" ? item.original_content : "",
      };

      for (const key of optionalTextFields) {
        if (hasOwn(item, key)) {
          const fieldValue = item[key];
          if (!isNullableString(fieldValue)) {
            errors.push(`${prefix}.${key} debe ser texto o null.`);
          } else {
            opportunity[key] = fieldValue;
          }
        }
      }

      if (hasOwn(item, "closing_date")) {
        let closingDate = item.closing_date;
        if (typeof closingDate === "string") {
          closingDate = closingDate.trim();
          if (closingDate.length === 0) closingDate = null;
        }
        if (
          closingDate !== null &&
          (typeof closingDate !== "string" || !isIsoDate(closingDate))
        ) {
          errors.push(`${prefix}.closing_date debe tener formato YYYY-MM-DD o ser null.`);
        } else {
          opportunity.closing_date = closingDate as string | null;
        }
      }

      if (hasOwn(item, "vacancies")) {
        const vacancies = item.vacancies;
        if (
          vacancies !== null &&
          (typeof vacancies !== "number" ||
            !Number.isSafeInteger(vacancies) ||
            vacancies < 1 ||
            vacancies > 2147483647)
        ) {
          errors.push(`${prefix}.vacancies debe ser un entero positivo o null.`);
        } else {
          opportunity.vacancies = vacancies as number | null;
        }
      }

      if (typeof item.original_content !== "string" || item.original_content.trim().length === 0) {
        errors.push(`${prefix}.original_content debe ser un texto no vacío.`);
      } else {
        opportunity.original_content = item.original_content;
      }

      if (hasOwn(item, "careers")) {
        const careers = item.careers;
        if (
          careers !== null &&
          (!Array.isArray(careers) ||
            careers.some(
              (career) => typeof career !== "string" || career.trim().length === 0,
            ))
        ) {
          errors.push(`${prefix}.careers debe ser un arreglo de textos no vacíos o null.`);
        } else {
          opportunity.careers = careers as string[] | null;
        }
      }

      opportunities.push(opportunity);
    });
  }

  if (errors.length > 0 || !sourceEmail || !Array.isArray(value.opportunities)) {
    return {
      valid: false,
      errors,
      ...(gmailMessageId ? { gmailMessageId } : {}),
    };
  }

  return {
    valid: true,
    payload: { source_email: sourceEmail, opportunities },
  };
}

function createSupabaseAdmin() {
  try {
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
  } catch {
    return null;
  }
}

async function recordErrorBestEffort(
  supabase: ReturnType<typeof createSupabaseAdmin>,
  gmailMessageId: string | undefined,
  errorCode: "invalid_payload" | "ingest_rpc_error",
): Promise<void> {
  if (!supabase || !gmailMessageId) return;

  try {
    await supabase.rpc("mark_opportunity_ingest_error", {
      p_gmail_message_id: gmailMessageId,
      p_error_code: errorCode,
    });
  } catch {
    // Keep the original response even if best-effort error registration fails.
  }
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return jsonResponse(405, { ok: false, error_code: "method_not_allowed" });
  }

  const sharedSecret = Deno.env.get("INGEST_SHARED_SECRET") ?? "";
  if (!sharedSecret) {
    return jsonResponse(500, { ok: false, error_code: "function_not_configured" });
  }

  const suppliedSecret = request.headers.get(SECRET_HEADER) ?? "";
  if (!secretsMatch(sharedSecret, suppliedSecret)) {
    return jsonResponse(401, { ok: false, error_code: "unauthorized" });
  }

  let requestBody: unknown;
  try {
    requestBody = await request.json();
  } catch {
    return jsonResponse(400, { ok: false, error_code: "invalid_json" });
  }

  if (!request.headers.get("content-type")?.toLowerCase().includes("application/json")) {
    const supabase = createSupabaseAdmin();
    await recordErrorBestEffort(
      supabase,
      getGmailMessageId(requestBody),
      "invalid_payload",
    );
    return jsonResponse(400, {
      ok: false,
      error_code: "invalid_payload",
      errors: ["Content-Type debe ser application/json."],
    });
  }

  let validation: ValidationResult;
  try {
    validation = validatePayload(requestBody);
  } catch {
    const supabase = createSupabaseAdmin();
    await recordErrorBestEffort(
      supabase,
      getGmailMessageId(requestBody),
      "ingest_rpc_error",
    );
    return jsonResponse(500, { ok: false, error_code: "ingest_unavailable" });
  }

  if (!validation.valid) {
    const supabase = createSupabaseAdmin();
    await recordErrorBestEffort(supabase, validation.gmailMessageId, "invalid_payload");
    return jsonResponse(400, {
      ok: false,
      error_code: "invalid_payload",
      errors: validation.errors,
    });
  }

  const supabase = createSupabaseAdmin();
  if (!supabase) {
    await recordErrorBestEffort(supabase, validation.payload.source_email.gmail_message_id, "ingest_rpc_error");
    return jsonResponse(500, { ok: false, error_code: "function_not_configured" });
  }

  try {
    const { data, error } = await supabase.rpc("ingest_opportunities", {
      p_source_email: validation.payload.source_email,
      p_opportunities: validation.payload.opportunities,
    });

    if (error) {
      await recordErrorBestEffort(
        supabase,
        validation.payload.source_email.gmail_message_id,
        "ingest_rpc_error",
      );
      return jsonResponse(500, { ok: false, error_code: "ingest_unavailable" });
    }

    if (!isRecord(data)) {
      await recordErrorBestEffort(
        supabase,
        validation.payload.source_email.gmail_message_id,
        "ingest_rpc_error",
      );
      return jsonResponse(500, { ok: false, error_code: "invalid_rpc_response" });
    }

    if (data.ok !== true) {
      return data.error_code === "invalid_payload" ||
          data.error_code === "invalid_gmail_message_id"
        ? jsonResponse(400, { ok: false, error_code: "invalid_payload" })
        : jsonResponse(500, { ok: false, error_code: "ingest_unavailable" });
    }

    return jsonResponse(200, data);
  } catch {
    await recordErrorBestEffort(
      supabase,
      validation.payload.source_email.gmail_message_id,
      "ingest_rpc_error",
    );
    return jsonResponse(500, { ok: false, error_code: "ingest_unavailable" });
  }
});

