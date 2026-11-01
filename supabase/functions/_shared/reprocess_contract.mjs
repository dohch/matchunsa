const textFields = [
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
];

const allowedOpportunityFields = new Set([
  ...textFields,
  "closing_date",
  "vacancies",
  "original_content",
  "careers",
]);

function isRecord(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isCalendarDate(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return false;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return false;
  const date = new Date(0);
  date.setUTCFullYear(year, month - 1, day);
  date.setUTCHours(0, 0, 0, 0);
  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

export function validateReprocessPayload(value) {
  const errors = [];
  if (!isRecord(value)) {
    return { valid: false, errors: ["El cuerpo debe ser un objeto JSON."] };
  }

  for (const key of Object.keys(value)) {
    if (key !== "gmail_message_id" && key !== "opportunities") {
      errors.push("El cuerpo contiene un campo no permitido.");
    }
  }

  if (
    typeof value.gmail_message_id !== "string" ||
    !value.gmail_message_id.trim() ||
    value.gmail_message_id !== value.gmail_message_id.trim()
  ) {
    errors.push("gmail_message_id debe ser un ID no vacío y exacto.");
  }

  if (!Array.isArray(value.opportunities) || value.opportunities.length === 0) {
    errors.push("opportunities debe ser un arreglo no vacío.");
  }

  const normalizedOpportunities = [];
  if (Array.isArray(value.opportunities)) {
    value.opportunities.forEach((item, index) => {
      const prefix = "opportunities[" + index + "]";
      if (!isRecord(item)) {
        errors.push(prefix + " debe ser un objeto.");
        return;
      }
      for (const key of Object.keys(item)) {
        if (!allowedOpportunityFields.has(key)) {
          errors.push(prefix + " contiene un campo no permitido.");
        }
      }

      const opportunity = { ...item };
      for (const field of textFields) {
        if (
          Object.prototype.hasOwnProperty.call(item, field) &&
          item[field] !== null &&
          typeof item[field] !== "string"
        ) {
          errors.push(prefix + "." + field + " debe ser texto o null.");
        }
      }

      if (Object.prototype.hasOwnProperty.call(item, "closing_date")) {
        if (item.closing_date === null ||
          (typeof item.closing_date === "string" && item.closing_date.trim() === "")) {
          opportunity.closing_date = null;
        } else if (
          typeof item.closing_date !== "string" ||
          !isCalendarDate(item.closing_date)
        ) {
          errors.push(prefix + ".closing_date debe usar YYYY-MM-DD o ser null.");
        }
      }

      if (
        Object.prototype.hasOwnProperty.call(item, "vacancies") &&
        item.vacancies !== null &&
        (typeof item.vacancies !== "number" ||
          !Number.isSafeInteger(item.vacancies) ||
          item.vacancies < 1 ||
          item.vacancies > 2147483647)
      ) {
        errors.push(prefix + ".vacancies debe ser un entero positivo o null.");
      }

      if (
        typeof item.original_content !== "string" ||
        !item.original_content.trim()
      ) {
        errors.push(prefix + ".original_content debe ser texto no vacío.");
      }

      if (
        Object.prototype.hasOwnProperty.call(item, "careers") &&
        item.careers !== null &&
        (!Array.isArray(item.careers) ||
          item.careers.some(
            (career) => typeof career !== "string" || !career.trim(),
          ))
      ) {
        errors.push(prefix + ".careers debe ser un arreglo de textos no vacíos o null.");
      }
      normalizedOpportunities.push(opportunity);
    });
  }

  if (errors.length > 0) return { valid: false, errors };
  return {
    valid: true,
    payload: {
      gmail_message_id: value.gmail_message_id,
      opportunities: normalizedOpportunities,
    },
  };
}

export function assertSuccessfulReprocessResult(data, gmailMessageId, expectedCount) {
  if (
    !isRecord(data) ||
    data.ok !== true ||
    data.reprocessed !== true ||
    data.duplicate === true ||
    data.gmail_message_id !== gmailMessageId ||
    data.opportunity_count !== expectedCount
  ) {
    throw new Error("La RPC no confirmó el reprocesamiento esperado.");
  }
  return data;
}
