type FoodLog = {
  id: string;
  logged_at?: string;
  meal_type?: string;
  label?: string | null;
  source?: string | null;
  raw_input?: string | null;
  saved_meal_id?: string | null;
};

type SavedMeal = {
  id: string;
  name: string;
  aliases?: string[];
  default_meal_type?: string;
};

type CleanupOptions = {
  date: string;
  confirmDelete: boolean;
  includeSavedMeals: boolean;
  savedMealName?: string;
  savedMealNameContains?: string;
  labelContains: string[];
  rawInputContains: string[];
};

const defaultSmokeTerms = ["Test", "protein yogurt", "generic food entry", "GB + Potato"];

const options = parseArgs(process.argv.slice(2));
const baseUrl = requiredEnv("FASTLOG_API_BASE_URL").replace(/\/+$/, "");
const jwt = requiredEnv("FASTLOG_TEST_JWT");

console.log(`FastLog smoke cleanup target: ${baseUrl}`);
console.log(`Date: ${options.date}`);
console.log(options.confirmDelete ? "Mode: confirmed delete" : "Mode: dry run");
console.log("Using FASTLOG_TEST_JWT from environment; token value is not printed.");

const foodLogs = await listFoodLogs(options.date);
const matchingLogs = foodLogs.filter((log) => matchesFoodLog(log, options));
const chatgptLogs = matchingLogs.filter((log) => log.source === "chatgpt");

console.log(`\nFood logs matching cleanup rules: ${matchingLogs.length}`);
for (const log of matchingLogs) {
  printFoodLog(log);
}

if (chatgptLogs.length > 0) {
  console.warn(
    `\nWarning: ${chatgptLogs.length} matched food log(s) have source="chatgpt". Some AI-created logs may be intentional.`
  );
}

let matchingSavedMeals: SavedMeal[] = [];

if (options.includeSavedMeals) {
  const savedMeals = await listSavedMeals();
  matchingSavedMeals = savedMeals.filter((meal) => matchesSavedMeal(meal, options));

  console.log(`\nSaved meals matching cleanup rules: ${matchingSavedMeals.length}`);
  for (const meal of matchingSavedMeals) {
    printSavedMeal(meal);
  }
} else {
  console.log("\nSaved meal cleanup is disabled. Pass --include-saved-meals with a saved meal name filter to target templates.");
}

if (!options.confirmDelete) {
  console.log("\nDry run only. Re-run with --confirm-delete to delete.");
  process.exit(0);
}

for (const log of matchingLogs) {
  await deleteResource(`/v1/food-logs/${encodeURIComponent(log.id)}`, `food log ${log.id}`);
}

for (const meal of matchingSavedMeals) {
  await deleteResource(`/v1/saved-meals/${encodeURIComponent(meal.id)}`, `saved meal ${meal.id}`);
}

console.log(`\nDeleted ${matchingLogs.length} food log(s) and ${matchingSavedMeals.length} saved meal(s).`);

function parseArgs(argv: string[]): CleanupOptions {
  const parsed: CleanupOptions = {
    date: "",
    confirmDelete: false,
    includeSavedMeals: false,
    labelContains: [],
    rawInputContains: []
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--today") {
      parsed.date = new Date().toISOString().slice(0, 10);
      continue;
    }

    if (arg === "--date") {
      parsed.date = readValue(argv, index, arg);
      index += 1;
      continue;
    }

    if (arg === "--confirm-delete") {
      parsed.confirmDelete = true;
      continue;
    }

    if (arg === "--include-saved-meals") {
      parsed.includeSavedMeals = true;
      continue;
    }

    if (arg === "--saved-meal-name") {
      parsed.savedMealName = readValue(argv, index, arg);
      index += 1;
      continue;
    }

    if (arg === "--saved-meal-name-contains") {
      parsed.savedMealNameContains = readValue(argv, index, arg);
      index += 1;
      continue;
    }

    if (arg === "--label-contains") {
      parsed.labelContains.push(readValue(argv, index, arg));
      index += 1;
      continue;
    }

    if (arg === "--raw-input-contains") {
      parsed.rawInputContains.push(readValue(argv, index, arg));
      index += 1;
      continue;
    }

    if (arg === "--help" || arg === "-h") {
      printUsage();
      process.exit(0);
    }

    fail(`Unknown argument: ${arg}`);
  }

  if (!parsed.date) {
    fail("Choose a cleanup date with --today or --date YYYY-MM-DD.");
  }

  if (!/^\d{4}-\d{2}-\d{2}$/.test(parsed.date)) {
    fail("--date must use YYYY-MM-DD.");
  }

  if (parsed.includeSavedMeals && !parsed.savedMealName && !parsed.savedMealNameContains) {
    fail("Saved meal cleanup requires --saved-meal-name or --saved-meal-name-contains.");
  }

  return parsed;
}

function readValue(argv: string[], index: number, flag: string): string {
  const value = argv[index + 1];
  if (!value || value.startsWith("--")) {
    fail(`${flag} requires a value.`);
  }
  return value;
}

function matchesFoodLog(log: FoodLog, cleanup: CleanupOptions): boolean {
  const defaultMatch =
    containsAny(log.label, defaultSmokeTerms) ||
    containsAny(log.raw_input, defaultSmokeTerms) ||
    log.source === "chatgpt";

  const labelMatch = cleanup.labelContains.some((term) => contains(log.label, term));
  const rawInputMatch = cleanup.rawInputContains.some((term) => contains(log.raw_input, term));

  return defaultMatch || labelMatch || rawInputMatch;
}

function matchesSavedMeal(meal: SavedMeal, cleanup: CleanupOptions): boolean {
  if (cleanup.savedMealName && meal.name === cleanup.savedMealName) return true;
  if (cleanup.savedMealNameContains && contains(meal.name, cleanup.savedMealNameContains)) return true;
  return false;
}

function containsAny(value: string | null | undefined, terms: string[]): boolean {
  return terms.some((term) => contains(value, term));
}

function contains(value: string | null | undefined, term: string): boolean {
  return String(value ?? "").toLowerCase().includes(term.toLowerCase());
}

async function listFoodLogs(date: string): Promise<FoodLog[]> {
  const body = await api("GET", `/v1/food-logs?date=${encodeURIComponent(date)}`);
  if (!isRecord(body) || !Array.isArray(body.food_logs)) {
    fail("Unexpected /v1/food-logs response shape.");
  }
  return body.food_logs as FoodLog[];
}

async function listSavedMeals(): Promise<SavedMeal[]> {
  const body = await api("GET", "/v1/saved-meals");
  if (!isRecord(body) || !Array.isArray(body.saved_meals)) {
    fail("Unexpected /v1/saved-meals response shape.");
  }
  return body.saved_meals as SavedMeal[];
}

async function deleteResource(path: string, label: string): Promise<void> {
  await api("DELETE", path);
  console.log(`Deleted ${label}`);
}

async function api(method: string, path: string): Promise<unknown> {
  const response = await fetch(baseUrl + path, {
    method,
    headers: {
      Authorization: `Bearer ${jwt}`
    }
  });
  const text = await response.text();
  const body = parseBody(text);

  if (!response.ok) {
    console.error(`${method} ${path} failed with status ${response.status}.`);
    console.error(formatBody(body));
    process.exit(1);
  }

  return body;
}

function parseBody(text: string): unknown {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function formatBody(body: unknown): string {
  return typeof body === "string" ? body : JSON.stringify(body, null, 2);
}

function printFoodLog(log: FoodLog): void {
  console.log(
    `- id=${log.id} label=${quote(log.label)} source=${quote(log.source)} raw_input=${quote(log.raw_input)} logged_at=${quote(log.logged_at)}`
  );
}

function printSavedMeal(meal: SavedMeal): void {
  console.log(`- id=${meal.id} name=${quote(meal.name)} aliases=${JSON.stringify(meal.aliases ?? [])}`);
}

function quote(value: string | null | undefined): string {
  return JSON.stringify(value ?? null);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    fail(`${name} is required.`);
  }
  return value;
}

function fail(message: string): never {
  console.error(message);
  process.exit(1);
}

function printUsage(): void {
  console.log(`Usage:
  npm run cleanup:smoke -- --today
  npm run cleanup:smoke -- --date YYYY-MM-DD
  npm run cleanup:smoke -- --today --confirm-delete
  npm run cleanup:smoke -- --today --include-saved-meals --saved-meal-name "GB + Potato"

Options:
  --today                         Clean smoke-test logs for today's UTC date.
  --date YYYY-MM-DD               Clean smoke-test logs for a specific date.
  --confirm-delete                Delete matched records. Omit for dry run.
  --include-saved-meals           Also inspect/delete saved meal templates.
  --saved-meal-name NAME          Exact saved meal name to target.
  --saved-meal-name-contains TEXT Saved meal name substring to target.
  --label-contains TEXT           Additional food-log label substring to target.
  --raw-input-contains TEXT       Additional food-log raw_input substring to target.
`);
}
