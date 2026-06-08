type SmokeResponse = {
  status: number;
  body: unknown;
};

const baseUrl = requiredEnv("FASTLOG_API_BASE_URL").replace(/\/+$/, "");
const jwt = requiredEnv("FASTLOG_TEST_JWT");
const runId = new Date().toISOString().replace(/[^0-9]/g, "").slice(0, 14);
const savedMealName = `Remote Smoke GB + Potato ${runId}`;
const rawHeaders = {
  Authorization: `Bearer ${jwt}`,
  "Content-Type": "application/json"
};

const checks: Array<{ label: string; run: () => Promise<SmokeResponse>; expected: number[] }> = [
  {
    label: "GET /v1/dashboard/today",
    run: () => request("GET", "/v1/dashboard/today"),
    expected: [200]
  },
  {
    label: "GET /v1/saved-meals",
    run: () => request("GET", "/v1/saved-meals"),
    expected: [200]
  },
  {
    label: "PATCH /v1/targets",
    run: () =>
      request("PATCH", "/v1/targets", {
        calories: 2400,
        protein_g: 180,
        carbs_g: 250,
        fat_g: 75,
        raw_input: "Remote smoke test target update"
      }),
    expected: [200]
  },
  {
    label: "POST /v1/saved-meals",
    run: () =>
      request("POST", "/v1/saved-meals", {
        name: savedMealName,
        aliases: [`remote smoke gb potato ${runId}`],
        default_meal_type: "dinner",
        calories: 610,
        protein_g: 50,
        carbs_g: 56,
        fat_g: 18
      }),
    expected: [201]
  },
  {
    label: "GET /v1/saved-meals/resolve?query=...",
    run: () => request("GET", `/v1/saved-meals/resolve?query=${encodeURIComponent(savedMealName)}`),
    expected: [200]
  },
  {
    label: "POST /v1/food-logs",
    run: () =>
      request("POST", "/v1/food-logs", {
        meal_type: "lunch",
        label: `Remote smoke one-off ${runId}`,
        calories: 500,
        protein_g: 40,
        carbs_g: 45,
        fat_g: 14,
        raw_input: "Remote smoke test one-off food log"
      }),
    expected: [201]
  }
];

let failed = false;

console.log(`Remote smoke target: ${baseUrl}`);
console.log("Using FASTLOG_TEST_JWT from environment; token value is not printed.");

for (const check of checks) {
  const response = await check.run();
  const ok = check.expected.includes(response.status);
  failed ||= !ok;

  console.log(`\n${ok ? "ok" : "FAIL"} ${check.label}`);
  console.log(`status: ${response.status}`);
  console.log(JSON.stringify(response.body, null, 2));
}

if (failed) {
  console.error("\nRemote smoke test failed.");
  process.exit(1);
}

console.log("\nRemote smoke test passed.");

async function request(method: string, path: string, body?: unknown): Promise<SmokeResponse> {
  const response = await fetch(baseUrl + path, {
    method,
    headers: rawHeaders,
    body: body === undefined ? undefined : JSON.stringify(body)
  });
  const text = await response.text();

  return {
    status: response.status,
    body: parseBody(text)
  };
}

function parseBody(text: string): unknown {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    console.error(`${name} is required.`);
    process.exit(1);
  }
  return value;
}
