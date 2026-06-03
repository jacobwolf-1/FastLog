import assert from "node:assert/strict";
import { createApp } from "../src/app.ts";
import { MemoryStore } from "../src/memory-store.ts";
import type { AiAuditLog, User } from "../src/domain.ts";

const user: User = { id: crypto.randomUUID(), email: "ai-action@example.test" };
const store = new MemoryStore();
const server = createApp({
  store,
  auth: async () => user,
  integrationProvider: "chatgpt"
});

await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
const address = server.address();
assert(address && typeof address === "object");
const baseUrl = "http://127.0.0.1:" + address.port;

try {
  const initialTargets = await api("PATCH", "/v1/targets", {
    calories: 2400,
    protein_g: 180,
    carbs_g: 250,
    fat_g: 75,
    source: "manual",
    provider: "claude",
    raw_input: "Set my targets to 2400 calories and 180 protein"
  });
  assert.equal(initialTargets.status, 200);
  assert.equal(initialTargets.body.calories, 2400);
  assert.equal(initialTargets.body.protein_g, 180);

  const savedMeal = await api("POST", "/v1/saved-meals", {
    name: "GB + Potato",
    aliases: ["ground beef potato", "beef potato", "gb potato"],
    default_meal_type: "dinner",
    calories: 610,
    protein_g: 50,
    carbs_g: 56,
    fat_g: 18,
    source: "manual",
    provider: "claude",
    raw_input: "Save GB + Potato"
  });
  assert.equal(savedMeal.status, 201);
  assert.equal(savedMeal.body.name, "GB + Potato");
  assert.equal(savedMeal.body.calories, 610);
  assert.equal(savedMeal.body.protein_g, 50);
  assert.equal(savedMeal.body.carbs_g, 56);
  assert.equal(savedMeal.body.fat_g, 18);

  const savedMeals = await api("GET", "/v1/saved-meals");
  assert.equal(savedMeals.status, 200);
  assert.equal(savedMeals.body.saved_meals.length, 1);
  assert.equal(savedMeals.body.saved_meals[0].id, savedMeal.body.id);

  const resolved = await api("GET", "/v1/saved-meals/resolve?query=GB%20%2B%20Potato");
  assert.equal(resolved.status, 200);
  assert.equal(resolved.body.match_status, "found");
  assert.equal(resolved.body.saved_meal.id, savedMeal.body.id);

  const savedMealLog = await api("POST", "/v1/saved-meals/" + savedMeal.body.id + "/log", {
    logged_at: today() + "T18:00:00.000Z",
    meal_type: "dinner",
    serving_multiplier: 1.5,
    source: "manual",
    provider: "other",
    raw_input: "Log 1.5x GB + Potato for dinner"
  });
  assert.equal(savedMealLog.status, 201);
  assert.equal(savedMealLog.body.label, "GB + Potato");
  assert.equal(savedMealLog.body.calories, 915);
  assert.equal(savedMealLog.body.protein_g, 75);
  assert.equal(savedMealLog.body.carbs_g, 84);
  assert.equal(savedMealLog.body.fat_g, 27);
  assert.equal(savedMealLog.body.saved_meal_id, savedMeal.body.id);
  assert.equal(savedMealLog.body.serving_multiplier, 1.5);
  assert.equal(savedMealLog.body.source, "chatgpt");

  const dashboardAfterSavedMeal = await api("GET", "/v1/dashboard/today");
  assert.equal(dashboardAfterSavedMeal.status, 200);
  assert.equal(dashboardAfterSavedMeal.body.totals.calories, 915);
  assert.equal(dashboardAfterSavedMeal.body.totals.protein_g, 75);
  assert.equal(dashboardAfterSavedMeal.body.totals.carbs_g, 84);
  assert.equal(dashboardAfterSavedMeal.body.totals.fat_g, 27);
  assert.equal(dashboardAfterSavedMeal.body.remaining.calories, 1485);

  const oneOffLog = await api("POST", "/v1/food-logs", {
    logged_at: today() + "T12:00:00.000Z",
    meal_type: "lunch",
    label: "One-off macro estimate",
    calories: 500,
    protein_g: 40,
    carbs_g: 45,
    fat_g: 14,
    source: "claude",
    provider: "other",
    raw_input: "Log a one-off lunch with 500 calories, 40 protein, 45 carbs, 14 fat"
  });
  assert.equal(oneOffLog.status, 201);
  assert.equal(oneOffLog.body.source, "chatgpt");

  const finalTargets = await api("PATCH", "/v1/targets", {
    calories: 2300,
    protein_g: 175,
    carbs_g: 220,
    fat_g: 70,
    source: "import",
    provider: "claude",
    raw_input: "Update my targets to 2300 calories and 175 protein"
  });
  assert.equal(finalTargets.status, 200);
  assert.equal(finalTargets.body.calories, 2300);
  assert.equal(finalTargets.body.protein_g, 175);

  const finalDashboard = await api("GET", "/v1/dashboard/today");
  assert.equal(finalDashboard.status, 200);
  assert.equal(finalDashboard.body.totals.calories, 1415);
  assert.equal(finalDashboard.body.totals.protein_g, 115);
  assert.equal(finalDashboard.body.totals.carbs_g, 129);
  assert.equal(finalDashboard.body.totals.fat_g, 41);
  assert.equal(finalDashboard.body.remaining.calories, 885);

  const audits = await store.listAiAuditLogs(user);
  assertAuditCount(audits, "updateTargets", 2);
  assertAuditCount(audits, "createSavedMeal", 1);
  assertAuditCount(audits, "logSavedMeal", 1);
  assertAuditCount(audits, "logFood", 1);

  for (const audit of audits) {
    assert.equal(audit.provider, "chatgpt");
    assert.equal((audit.request_payload as any).source, undefined);
    assert.equal((audit.request_payload as any).provider, undefined);
  }

  const logSavedMealAudit = audits.find((audit) => audit.action === "logSavedMeal");
  assert(logSavedMealAudit);
  assert.equal(logSavedMealAudit.created_resource_type, "food_log");
  assert.equal(logSavedMealAudit.created_resource_id, savedMealLog.body.id);

  const createSavedMealAudit = audits.find((audit) => audit.action === "createSavedMeal");
  assert(createSavedMealAudit);
  assert.equal(createSavedMealAudit.created_resource_type, "saved_meal");
  assert.equal(createSavedMealAudit.created_resource_id, savedMeal.body.id);

  console.log("all AI Action smoke tests passed");
} finally {
  await new Promise<void>((resolve) => server.close(() => resolve()));
}

async function api(method: string, path: string, body?: unknown) {
  const response = await fetch(baseUrl + path, {
    method,
    headers: {
      Authorization: "Bearer test-user",
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

function assertAuditCount(audits: AiAuditLog[], action: string, expected: number) {
  assert.equal(audits.filter((audit) => audit.action === action).length, expected, action);
}

function today() {
  return new Date().toISOString().slice(0, 10);
}
