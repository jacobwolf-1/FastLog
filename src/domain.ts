export const mealTypes = ['breakfast', 'lunch', 'dinner', 'snack', 'unspecified'] as const;
export const sources = ['manual', 'shortcut', 'chatgpt', 'claude', 'import'] as const;
export const aiProviders = ['chatgpt', 'claude', 'other'] as const;

export type MealType = typeof mealTypes[number];
export type Source = typeof sources[number];
export type AiProvider = typeof aiProviders[number];

export type User = {
  id: string;
  email?: string | null;
};

export type Nutrition = {
  calories: number;
  protein_g?: number | null;
  carbs_g?: number | null;
  fat_g?: number | null;
  fiber_g?: number | null;
  sodium_mg?: number | null;
  sugar_g?: number | null;
  potassium_mg?: number | null;
};

export type FoodLog = Nutrition & {
  id: string;
  user_id: string;
  logged_at: string;
  meal_type: MealType;
  label?: string | null;
  saved_meal_id?: string | null;
  serving_multiplier: number;
  source: Source;
  raw_input?: string | null;
  created_at: string;
  updated_at: string;
};

export type DailyTargets = Nutrition & {
  id: string;
  user_id: string;
  effective_date: string;
  created_at: string;
};

export type SavedMeal = Nutrition & {
  id: string;
  user_id: string;
  name: string;
  normalized_name: string;
  default_meal_type: MealType;
  aliases: string[];
  created_at: string;
  updated_at: string;
};

export type SavedMealResolution =
  | {
      match_status: 'found';
      match_type:
        | 'exact_name'
        | 'exact_alias'
        | 'normalized_name'
        | 'normalized_alias'
        | 'fuzzy_name'
        | 'fuzzy_alias';
      confidence: number;
      saved_meal: SavedMeal;
    }
  | {
      match_status: 'not_found';
      message: 'No saved meal template found.';
    };

export type WeightEntry = {
  id: string;
  user_id: string;
  measured_at: string;
  weight_lb: number;
  source: 'apple_health' | 'manual' | 'import';
  created_at: string;
};

export type AiAuditLog = {
  id: string;
  user_id: string;
  provider: AiProvider;
  action: string;
  raw_user_text?: string | null;
  request_payload?: unknown;
  response_payload?: unknown;
  created_resource_type?: string | null;
  created_resource_id?: string | null;
  created_at: string;
};

export const nutritionKeys = [
  'protein_g',
  'carbs_g',
  'fat_g',
  'fiber_g',
  'sodium_mg',
  'sugar_g',
  'potassium_mg'
] as const;

export function id(): string {
  return crypto.randomUUID();
}

export function nowIso(): string {
  return new Date().toISOString();
}

export function todayIsoDate(): string {
  return new Date().toISOString().slice(0, 10);
}

export function isoDateFromTimestamp(value: string): string {
  return new Date(value).toISOString().slice(0, 10);
}

export function normalizeMealQuery(input: string): string {
  return input.toLowerCase().replace(/[^a-z0-9]+/g, '');
}

export function assertDate(value: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw badRequest('Expected date as YYYY-MM-DD.');
  }
  return value;
}

export function assertMealType(value: unknown): MealType {
  if (value === undefined || value === null || value === '') return 'unspecified';
  if (typeof value === 'string' && mealTypes.includes(value as MealType)) return value as MealType;
  throw badRequest('Invalid meal_type.');
}

export function assertSource(value: unknown): Source {
  if (value === undefined || value === null || value === '') return 'manual';
  if (typeof value === 'string' && sources.includes(value as Source)) return value as Source;
  throw badRequest('Invalid source.');
}

export function maybeAiProvider(value: unknown): AiProvider | null {
  if (typeof value !== 'string') return null;
  if (value === 'chatgpt' || value === 'claude' || value === 'other') return value;
  return null;
}

export function assertPositiveNumber(value: unknown, field: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    throw badRequest(`${field} must be a positive number.`);
  }
  return value;
}

export function assertNonNegativeOptional(value: unknown, field: string): number | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) {
    throw badRequest(`${field} must be a non-negative number.`);
  }
  return value;
}

export function parseNutrition(body: Record<string, unknown>): Nutrition {
  const result: Nutrition = {
    calories: Math.round(assertPositiveNumber(body.calories, 'calories'))
  };

  for (const key of nutritionKeys) {
    result[key] = assertNonNegativeOptional(body[key], key);
  }

  return result;
}


export function parseNutritionPatch(body: Record<string, unknown>): Partial<Nutrition> {
  const result: Partial<Nutrition> = {};

  if ('calories' in body) {
    result.calories = Math.round(assertPositiveNumber(body.calories, 'calories'));
  }

  for (const key of nutritionKeys) {
    if (key in body) {
      result[key] = assertNonNegativeOptional(body[key], key);
    }
  }

  return result;
}

export function scaleNutrition(nutrition: Nutrition, multiplier: number): Nutrition {
  const scaled: Nutrition = {
    calories: Math.round(nutrition.calories * multiplier)
  };

  for (const key of nutritionKeys) {
    const value = nutrition[key];
    scaled[key] = value == null ? value : value * multiplier;
  }

  return scaled;
}

export function zeroTotals(): Required<Nutrition> {
  return {
    calories: 0,
    protein_g: 0,
    carbs_g: 0,
    fat_g: 0,
    fiber_g: 0,
    sodium_mg: 0,
    sugar_g: 0,
    potassium_mg: 0
  };
}

export function sumLogs(logs: FoodLog[]): Required<Nutrition> {
  const totals = zeroTotals();
  for (const log of logs) {
    totals.calories += log.calories;
    for (const key of nutritionKeys) {
      totals[key] += Number(log[key] ?? 0);
    }
  }
  return totals;
}

export function remaining(targets: DailyTargets | null, totals: Required<Nutrition>): Required<Nutrition> {
  const result = zeroTotals();
  if (!targets) return result;

  result.calories = targets.calories - totals.calories;
  for (const key of nutritionKeys) {
    result[key] = Number(targets[key] ?? 0) - totals[key];
  }
  return result;
}

export function similarity(left: string, right: string): number {
  if (left === right) return 1;
  if (!left || !right) return 0;

  const leftGrams = ngrams(left);
  const rightGrams = ngrams(right);
  let overlap = 0;
  for (const gram of leftGrams) {
    if (rightGrams.has(gram)) overlap += 1;
  }
  return (2 * overlap) / (leftGrams.size + rightGrams.size);
}

function ngrams(value: string): Set<string> {
  if (value.length <= 2) return new Set([value]);
  const grams = new Set<string>();
  for (let index = 0; index < value.length - 1; index += 1) {
    grams.add(value.slice(index, index + 2));
  }
  return grams;
}

export function badRequest(message: string): HttpError {
  return new HttpError(400, message);
}

export function unauthorized(message = 'Missing or invalid authentication.'): HttpError {
  return new HttpError(401, message);
}

export function notFound(message = 'Not found.'): HttpError {
  return new HttpError(404, message);
}

export class HttpError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}
