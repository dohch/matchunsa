import assert from "node:assert/strict";
import test from "node:test";
import {
  assertSuccessfulReprocessResult,
  validateReprocessPayload,
} from "./reprocess_contract.mjs";

const validOpportunity = {
  title: "Developer .NET",
  company: "OSMIOZ",
  academic_profile: "BACHILLER",
  location: "CALLAO",
  closing_date: "2027-01-29",
  vacancies: 3,
  requirements: "Requisitos",
  desired_knowledge: "Conocimientos",
  functions: "Funciones",
  additional_information: "Información adicional",
  application_url: "https://forms.cloud.microsoft/r/test",
  application_email: null,
  application_phone: null,
  cv_type: "SIMPLE",
  original_content: "Fragmento original de la convocatoria",
  careers: ["Carrera de prueba"],
};

test("accepts the manual reprocess payload and preserves its exact Gmail ID", () => {
  const result = validateReprocessPayload({
    gmail_message_id: "gmail-osmioz-exact-id",
    opportunities: [validOpportunity, validOpportunity, validOpportunity, validOpportunity],
  });
  assert.equal(result.valid, true);
  assert.equal(result.payload.gmail_message_id, "gmail-osmioz-exact-id");
  assert.equal(result.payload.opportunities.length, 4);
});

test("rejects an empty opportunity list to prevent accidental clearing", () => {
  const result = validateReprocessPayload({
    gmail_message_id: "gmail-osmioz-exact-id",
    opportunities: [],
  });
  assert.equal(result.valid, false);
});

test("rejects unknown fields and malformed field types", () => {
  const result = validateReprocessPayload({
    gmail_message_id: "gmail-osmioz-exact-id",
    opportunities: [{
      ...validOpportunity,
      application_mode: "remote",
      vacancies: "3",
    }],
  });
  assert.equal(result.valid, false);
  assert.ok(result.errors.some((error) => error.includes("no permitido")));
  assert.ok(result.errors.some((error) => error.includes("vacancies")));
});

test("rejects a whitespace-altered Gmail ID", () => {
  const result = validateReprocessPayload({
    gmail_message_id: " gmail-osmioz-exact-id ",
    opportunities: [validOpportunity],
  });
  assert.equal(result.valid, false);
});

test("rejects invalid dates and accepts nullable fields", () => {
  const invalidDate = validateReprocessPayload({
    gmail_message_id: "gmail-osmioz-exact-id",
    opportunities: [{ ...validOpportunity, closing_date: "2027-02-29" }],
  });
  assert.equal(invalidDate.valid, false);

  const nullable = validateReprocessPayload({
    gmail_message_id: "gmail-osmioz-exact-id",
    opportunities: [{
      ...validOpportunity,
      title: null,
      closing_date: "",
      vacancies: null,
      careers: null,
    }],
  });
  assert.equal(nullable.valid, true);
  assert.equal(nullable.payload.opportunities[0].closing_date, null);
});

test("accepts only explicit confirmation for the same ID and count", () => {
  const response = {
    ok: true,
    reprocessed: true,
    gmail_message_id: "gmail-osmioz-exact-id",
    opportunity_count: 4,
  };
  assert.equal(
    assertSuccessfulReprocessResult(response, "gmail-osmioz-exact-id", 4),
    response,
  );
  assert.throws(
    () => assertSuccessfulReprocessResult(
      { ...response, duplicate: true, reprocessed: false },
      "gmail-osmioz-exact-id",
      4,
    ),
  );
  assert.throws(
    () => assertSuccessfulReprocessResult(
      { ...response, gmail_message_id: "another-email" },
      "gmail-osmioz-exact-id",
      4,
    ),
  );
  assert.throws(
    () => assertSuccessfulReprocessResult(response, "gmail-osmioz-exact-id", 3),
  );
});
