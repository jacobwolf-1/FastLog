import assert from "node:assert/strict";
import { createApp } from "../src/app.ts";
import { MemoryStore } from "../src/memory-store.ts";
import type { User } from "../src/domain.ts";

const userA: User = { id: crypto.randomUUID(), email: "a@example.test" };
const userB: User = { id: crypto.randomUUID(), email: "b@example.test" };
const store = new MemoryStore();
const server = createApp({
  store,
  auth: async (request) => {
    const token = request.headers.authorization?.replace("Bearer ", "");
    if (token === "user-a") return userA;
    if (token === "user-b") return userB;
    throw new Error("test auth failed");
  },
  integrationProvider: "chatgpt"
});

await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
const address = server.address();
assert(address && typeof address === "object");
const baseUrl = "http://127.0.0.1:" + address.port;

try {
  await testMigrationStaticExpectations();
  await testSeedEquivalentWorks();
  await testCreateTarget();
  const patchedLog = await testCreateFoodLogAndDashboardTotals();
  await testPatchFoodLog(patchedLog.id);
  await testDeleteFoodLog();
  const meal = await testCreateAndResolveSavedMeal();
  const log = await testLogSavedMealWithServingMultiplier(meal.id);
  await testPatchSavedMealAndReplaceAliasesWithoutMutatingHistoricalLog(meal.id, log.id);
  await testSavedMealDeletePreservesHistoricalFoodLogs(meal.id, log.id);
  await testRlsIsolationAssumptions();
  console.log("all integration tests passed");
} finally {
  await new Promise<void>((resolve) => server.close(() => resolve()));
}

async function testMigrationStaticExpectations() {
  const response = await api("PATCH", "/v1/targets", {
    calories: 2300,
    protein_g: 180,
    carbs_g: 220,
    fat_g: 70,
    effective_date: today()
  });
  assert.equal(response.status, 200);
  console.log("ok - migration applies static assumptions through executable API path");
}

async function testSeedEquivalentWorks() {
  const response = await api("POST", "/v1/saved-meals", {
    name: "Seed Yogurt",
    aliases: ["protein yogurt"],
    calories: 220,
    protein_g: 25,
    carbs_g: 15,
    fat_g: 7
  });
  assert.equal(response.status, 201);
  console.log("ok - seed-equivalent data creation works");
}

async function testCreateTarget() {
  const response = await api("GET", "/v1/targets/current");
  assert.equal(response.status, 200);
  assert.equal(response.body.calories, 2300);
  assert.equal(response.body.protein_g, 180);
  console.log("ok - create target");
}

async function testCreateFoodLogAndDashboardTotals() {
  const response = await api("POST", "/v1/food-logs", {
    logged_at: today() + "T12:00:00.000Z",
    meal_type: "lunch",
    label: "Chicken + potatoes",
    calories: 610,
    protein_g: 55,
    carbs_g: 58,
    fat_g: 12,
    source: "claude",
    provider: "other",
    raw_input: "Log chicken and potatoes for lunch"
  });
  assert.equal(response.status, 201);
  assert.equal(response.body.source, "chatgpt");

  const dashboard = await api("GET", "/v1/dashboard?date=" + today());
  assert.equal(dashboard.status, 200);
  assert.equal(dashboard.body.totals.calories, 610);
  assert.equal(dashboard.body.totals.protein_g, 55);
  assert.equal(dashboard.body.remaining.calories, 1690);

  const audits = await store.listAiAuditLogs(userA);
  const logFoodAudit = audits.find((audit) => audit.action === "logFood" && audit.provider === "chatgpt");
  assert(logFoodAudit);
  assert.equal((logFoodAudit.request_payload as any).source, undefined);
  assert.equal((logFoodAudit.request_payload as any).provider, undefined);
  console.log("ok - create food log, compute dashboard totals, and audit AI logFood");
  return response.body;
}

async function testPatchFoodLog(foodLogId: string) {
  const response = await api("PATCH", "/v1/food-logs/" + foodLogId, {
    label: "Edited chicken + potatoes",
    meal_type: "dinner",
    calories: 700,
    protein_g: 60,
    carbs_g: 70,
    fat_g: 14,
    source: "manual",
    provider: "claude",
    raw_input: "client attempted to spoof source while editing"
  });
  assert.equal(response.status, 200);
  assert.equal(response.body.label, "Edited chicken + potatoes");
  assert.equal(response.body.meal_type, "dinner");
  assert.equal(response.body.calories, 700);
  assert.equal(response.body.protein_g, 60);
  assert.equal(response.body.source, "chatgpt");

  const dashboard = await api("GET", "/v1/dashboard?date=" + today());
  assert.equal(dashboard.body.totals.calories, 700);
  console.log("ok - patch food log while ignoring spoofed source/provider");
}

async function testDeleteFoodLog() {
  const created = await api("POST", "/v1/food-logs", {
    logged_at: today() + "T14:00:00.000Z",
    label: "Delete me",
    calories: 123,
    protein_g: 10
  });
  assert.equal(created.status, 201);

  const deleted = await api("DELETE", "/v1/food-logs/" + created.body.id);
  assert.equal(deleted.status, 200);

  const logs = await api("GET", "/v1/food-logs?date=" + today());
  assert.equal(logs.body.food_logs.some((log: any) => log.id === created.body.id), false);
  console.log("ok - delete own food log");
}

async function testCreateAndResolveSavedMeal() {
  const create = await api("POST", "/v1/saved-meals", {
    name: "GB + Potato",
    aliases: ["ground beef potato", "beef potato", "gb potato"],
    calories: 610,
    protein_g: 50,
    carbs_g: 56,
    fat_g: 18,
    fiber_g: 5,
    sodium_mg: 850,
    provider: "claude",
    source: "manual"
  });
  assert.equal(create.status, 201);

  const exactAlias = await api("GET", "/v1/saved-meals/resolve?query=gb%20potato");
  assert.equal(exactAlias.status, 200);
  assert.equal(exactAlias.body.match_status, "found");
  assert.equal(exactAlias.body.match_type, "exact_alias");

  const normalizedName = await api("GET", "/v1/saved-meals/resolve?query=GB-Potato");
  assert.equal(normalizedName.body.match_status, "found");
  assert.equal(normalizedName.body.match_type, "normalized_name");

  const fuzzy = await api("GET", "/v1/saved-meals/resolve?query=gb%20potao");
  assert.equal(fuzzy.body.match_status, "found");

  const notFound = await api("GET", "/v1/saved-meals/resolve?query=banana%20pancakes");
  assert.equal(notFound.body.match_status, "not_found");

  const audits = await store.listAiAuditLogs(userA);
  const createMealAudit = audits.find((audit) => audit.action === "createSavedMeal" && audit.provider === "chatgpt");
  assert(createMealAudit);
  assert.equal((createMealAudit.request_payload as any).source, undefined);
  assert.equal((createMealAudit.request_payload as any).provider, undefined);
  console.log("ok - create saved meal and resolve by exact, normalized, fuzzy, and not_found paths");
  return create.body;
}

async function testLogSavedMealWithServingMultiplier(savedMealId: string) {
  const response = await api("POST", "/v1/saved-meals/" + savedMealId + "/log", {
    logged_at: today() + "T18:00:00.000Z",
    meal_type: "dinner",
    serving_multiplier: 1.5,
    source: "claude",
    provider: "claude",
    raw_input: "Log 1.5x GB + Potato for dinner"
  });
  assert.equal(response.status, 201);
  assert.equal(response.body.calories, 915);
  assert.equal(response.body.protein_g, 75);
  assert.equal(response.body.carbs_g, 84);
  assert.equal(response.body.fat_g, 27);
  assert.equal(response.body.saved_meal_id, savedMealId);
  assert.equal(response.body.source, "chatgpt");

  const audits = await store.listAiAuditLogs(userA);
  const logSavedMealAudit = audits.find((audit) => audit.action === "logSavedMeal" && audit.provider === "chatgpt");
  assert(logSavedMealAudit);
  assert.equal((logSavedMealAudit.request_payload as any).source, undefined);
  assert.equal((logSavedMealAudit.request_payload as any).provider, undefined);
  console.log("ok - log saved meal with serving multiplier, override spoofed source, and audit AI logSavedMeal");
  return response.body;
}

async function testPatchSavedMealAndReplaceAliasesWithoutMutatingHistoricalLog(savedMealId: string, foodLogId: string) {
  const beforeLogs = await api("GET", "/v1/food-logs?date=" + today());
  const beforeHistorical = beforeLogs.body.food_logs.find((log: any) => log.id === foodLogId);
  assert(beforeHistorical);
  assert.equal(beforeHistorical.calories, 915);
  assert.equal(beforeHistorical.protein_g, 75);

  const response = await api("PATCH", "/v1/saved-meals/" + savedMealId, {
    name: "GB + Rice",
    aliases: ["gb rice", "beef rice"],
    default_meal_type: "lunch",
    calories: 700,
    protein_g: 52,
    carbs_g: 80,
    fat_g: 16,
    source: "manual",
    provider: "claude"
  });
  assert.equal(response.status, 200);
  assert.equal(response.body.name, "GB + Rice");
  assert.deepEqual(response.body.aliases, ["gb rice", "beef rice"]);
  assert.equal(response.body.calories, 700);

  const oldAlias = await api("GET", "/v1/saved-meals/resolve?query=gb%20potato");
  assert.equal(oldAlias.body.match_status, "not_found");

  const newAlias = await api("GET", "/v1/saved-meals/resolve?query=beef%20rice");
  assert.equal(newAlias.body.match_status, "found");
  assert.equal(newAlias.body.saved_meal.id, savedMealId);

  const afterLogs = await api("GET", "/v1/food-logs?date=" + today());
  const afterHistorical = afterLogs.body.food_logs.find((log: any) => log.id === foodLogId);
  assert(afterHistorical);
  assert.equal(afterHistorical.calories, 915);
  assert.equal(afterHistorical.protein_g, 75);
  assert.equal(afterHistorical.carbs_g, 84);
  assert.equal(afterHistorical.fat_g, 27);
  console.log("ok - patch saved meal, replace aliases, and preserve historical food log macros");
}

async function testSavedMealDeletePreservesHistoricalFoodLogs(savedMealId: string, foodLogId: string) {
  const deleted = await api("DELETE", "/v1/saved-meals/" + savedMealId);
  assert.equal(deleted.status, 200);

  const logs = await api("GET", "/v1/food-logs?date=" + today());
  const historical = logs.body.food_logs.find((log: any) => log.id === foodLogId);
  assert(historical);
  assert.equal(historical.saved_meal_id, null);
  assert.equal(historical.calories, 915);
  assert.equal(historical.protein_g, 75);
  console.log("ok - saved meal delete preserves historical food logs and clears saved_meal_id");
}

async function testRlsIsolationAssumptions() {
  const targetB = await api("PATCH", "/v1/targets", { calories: 1800, effective_date: today() }, "user-b");
  assert.equal(targetB.status, 200);

  const dashboardA = await api("GET", "/v1/dashboard?date=" + today(), undefined, "user-a");
  const dashboardB = await api("GET", "/v1/dashboard?date=" + today(), undefined, "user-b");
  assert.notEqual(dashboardA.body.targets.calories, dashboardB.body.targets.calories);
  assert.equal(dashboardB.body.logs.length, 0);

  const crossUserLog = await api("POST", "/v1/food-logs", {
    calories: 100,
    saved_meal_id: "not-owned-by-user-a"
  });
  assert.equal(crossUserLog.status, 400);
  console.log("ok - RLS/user isolation assumptions");
}

async function api(method: string, path: string, body?: unknown, token = "user-a") {
  const response = await fetch(baseUrl + path, {
    method,
    headers: {
      Authorization: "Bearer " + token,
      ...(body ? { "Content-Type": "application/json" } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await response.text();
  return {
    status: response.status,
    body: text ? JSON.parse(text) : null
  };
}

function today() {
  return new Date().toISOString().slice(0, 10);
}
