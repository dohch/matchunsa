import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../Código.gs", import.meta.url), "utf8");
const forbiddenExternalCall = () => {
  throw new Error("Las pruebas locales no deben llamar servicios externos.");
};
const context = {
  console: { log() {} },
  Logger: { log() {} },
  GmailApp: new Proxy({}, { get: () => forbiddenExternalCall }),
  UrlFetchApp: new Proxy({}, { get: () => forbiddenExternalCall }),
  PropertiesService: new Proxy({}, { get: () => forbiddenExternalCall }),
  LockService: new Proxy({}, { get: () => forbiddenExternalCall }),
};
vm.createContext(context);
vm.runInContext(source, context);

test("Apps Script parser local suite passes without external services", () => {
  const result = vm.runInContext("runLocalParserTests()", context);
  assert.match(result, /42 de 42/);
});

test("Apps Script manual reprocess contract passes success and failure cases offline", () => {
  const result = vm.runInContext("runLocalReprocessTests()", context);
  assert.match(result, /7 de 7/);
});
