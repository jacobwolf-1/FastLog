import {
  assertDate,
  assertMealType,
  assertPositiveNumber,
  badRequest,
  normalizeMealQuery,
  nowIso,
  parseNutrition,
  parseNutritionPatch,
  remaining,
  scaleNutrition,
  similarity,
  sumLogs,
  todayIsoDate,
  type AiAuditLog,
  type DailyTargets,
  type FoodLog,
  type SavedMeal,
  type SavedMealResolution,
  type User,
  type WeightEntry
} from './domain.ts';
import type {
  CreateFoodLogInput,
  CreateSavedMealInput,
  CreateWeightEntryInput,
  FastLogStore,
  LogSavedMealInput,
  UpdateFoodLogInput,
  UpdateSavedMealInput,
  UpdateTargetsInput,
  WeightTrend
} from './store.ts';

const fuzzyThreshold = 0.72;

export class SupabaseStore implements FastLogStore {
  private readonly supabaseUrl: string;
  private readonly anonKey: string;
  private readonly bearerToken: string;

  constructor(supabaseUrl: string, anonKey: string, bearerToken: string) {
    this.supabaseUrl = supabaseUrl;
    this.anonKey = anonKey;
    this.bearerToken = bearerToken;
  }

  async ensureProfile(user: User): Promise<void> {
    await this.request('/profiles', {
      method: 'POST',
      body: [{ id: user.id, email: user.email ?? null }],
      query: { on_conflict: 'id' },
      headers: { Prefer: 'resolution=merge-duplicates' }
    });
  }

  async createFoodLog(user: User, input: CreateFoodLogInput): Promise<FoodLog> {
    const nutrition = parseNutrition(input as Record<string, unknown>);
    const row = {
      user_id: user.id,
      logged_at: input.logged_at ?? nowIso(),
      meal_type: assertMealType(input.meal_type),
      label: input.label ?? null,
      ...nutrition,
      saved_meal_id: input.saved_meal_id ?? null,
      serving_multiplier:
        input.serving_multiplier == null ? 1 : assertPositiveNumber(input.serving_multiplier, 'serving_multiplier'),
      source: input.source ?? 'manual',
      raw_input: input.raw_input ?? null
    };

    const rows = await this.request<FoodLog[]>('/food_logs', {
      method: 'POST',
      body: row,
      headers: { Prefer: 'return=representation' }
    });
    return rows[0];
  }



  async updateFoodLog(user: User, foodLogId: string, input: UpdateFoodLogInput): Promise<FoodLog> {
    const patch: Record<string, unknown> = { ...parseNutritionPatch(input as Record<string, unknown>) };
    if ("logged_at" in input) patch.logged_at = input.logged_at;
    if ("meal_type" in input) patch.meal_type = assertMealType(input.meal_type);
    if ("label" in input) patch.label = input.label ?? null;
    if ("raw_input" in input) patch.raw_input = input.raw_input ?? null;

    const rows = await this.request<FoodLog[]>("/food_logs", {
      method: "PATCH",
      query: {
        id: "eq." + foodLogId,
        user_id: "eq." + user.id
      },
      body: patch,
      headers: { Prefer: "return=representation" }
    });
    if (!rows[0]) throw badRequest("Food log not found.");
    return rows[0];
  }

  async deleteFoodLog(user: User, foodLogId: string): Promise<void> {
    const rows = await this.request<FoodLog[]>("/food_logs", {
      method: "DELETE",
      query: {
        id: "eq." + foodLogId,
        user_id: "eq." + user.id
      },
      headers: { Prefer: "return=representation" }
    });
    if (!rows[0]) throw badRequest("Food log not found.");
  }

  async listFoodLogs(user: User, date: string): Promise<FoodLog[]> {
    assertDate(date);
    const start = `${date}T00:00:00.000Z`;
    const next = new Date(`${date}T00:00:00.000Z`);
    next.setUTCDate(next.getUTCDate() + 1);
    return this.request<FoodLog[]>('/food_logs', {
      query: {
        user_id: `eq.${user.id}`,
        logged_at: [`gte.${start}`, `lt.${next.toISOString()}`],
        order: 'logged_at.asc'
      }
    });
  }

  async getDashboard(user: User, date: string) {
    const logs = await this.listFoodLogs(user, date);
    const targets = await this.getCurrentTargets(user, date);
    const totals = sumLogs(logs);
    return {
      date,
      targets,
      totals,
      remaining: remaining(targets, totals),
      logs
    };
  }

  async getCurrentTargets(user: User, date = todayIsoDate()): Promise<DailyTargets | null> {
    assertDate(date);
    const rows = await this.request<DailyTargets[]>('/daily_targets', {
      query: {
        user_id: `eq.${user.id}`,
        effective_date: `lte.${date}`,
        order: 'effective_date.desc',
        limit: '1'
      }
    });
    return rows[0] ?? null;
  }

  async updateTargets(user: User, input: UpdateTargetsInput): Promise<DailyTargets> {
    const nutrition = parseNutrition(input as Record<string, unknown>);
    const effectiveDate = assertDate(input.effective_date ?? todayIsoDate());
    const rows = await this.request<DailyTargets[]>('/daily_targets', {
      method: 'POST',
      body: {
        user_id: user.id,
        ...nutrition,
        effective_date: effectiveDate
      },
      query: { on_conflict: 'user_id,effective_date' },
      headers: { Prefer: 'resolution=merge-duplicates,return=representation' }
    });
    return rows[0];
  }

  async listSavedMeals(user: User): Promise<SavedMeal[]> {
    const meals = await this.request<Omit<SavedMeal, 'aliases'>[]>('/saved_meals', {
      query: {
        user_id: `eq.${user.id}`,
        order: 'name.asc'
      }
    });
    const aliases = await this.request<Array<{ saved_meal_id: string; alias: string }>>('/saved_meal_aliases', {
      query: { user_id: `eq.${user.id}` }
    });
    return meals.map((meal) => ({
      ...meal,
      aliases: aliases.filter((alias) => alias.saved_meal_id === meal.id).map((alias) => alias.alias)
    }));
  }

  async createSavedMeal(user: User, input: CreateSavedMealInput): Promise<SavedMeal> {
    if (!input.name || !input.name.trim()) throw badRequest('name is required.');
    const nutrition = parseNutrition(input as Record<string, unknown>);
    const rows = await this.request<SavedMeal[]>('/saved_meals', {
      method: 'POST',
      body: {
        user_id: user.id,
        name: input.name.trim(),
        default_meal_type: assertMealType(input.default_meal_type),
        ...nutrition
      },
      headers: { Prefer: 'return=representation' }
    });
    const meal = rows[0];
    const aliases = [...new Set((input.aliases ?? []).map((alias) => alias.trim()).filter(Boolean))];
    if (aliases.length > 0) {
      await this.request('/saved_meal_aliases', {
        method: 'POST',
        body: aliases.map((alias) => ({ user_id: user.id, saved_meal_id: meal.id, alias }))
      });
    }
    return { ...meal, aliases };
  }



  async updateSavedMeal(user: User, savedMealId: string, input: UpdateSavedMealInput): Promise<SavedMeal> {
    const patch: Record<string, unknown> = { ...parseNutritionPatch(input as Record<string, unknown>) };
    if ("name" in input) {
      if (!input.name || !input.name.trim()) throw badRequest("name cannot be blank.");
      patch.name = input.name.trim();
    }
    if ("default_meal_type" in input) patch.default_meal_type = assertMealType(input.default_meal_type);

    let meal: SavedMeal | null = null;
    if (Object.keys(patch).length > 0) {
      const rows = await this.request<SavedMeal[]>("/saved_meals", {
        method: "PATCH",
        query: {
          id: "eq." + savedMealId,
          user_id: "eq." + user.id
        },
        body: patch,
        headers: { Prefer: "return=representation" }
      });
      meal = rows[0] ?? null;
    } else {
      meal = (await this.listSavedMeals(user)).find((savedMeal) => savedMeal.id === savedMealId) ?? null;
    }
    if (!meal) throw badRequest("Saved meal not found.");

    if ("aliases" in input) {
      const aliases = [...new Set((input.aliases ?? []).map((alias) => alias.trim()).filter(Boolean))];
      const normalizedAliases = aliases.map(normalizeMealQuery);
      if (new Set(normalizedAliases).size !== normalizedAliases.length) throw badRequest("Duplicate aliases are not allowed.");

      await this.request("/saved_meal_aliases", {
        method: "DELETE",
        query: {
          user_id: "eq." + user.id,
          saved_meal_id: "eq." + savedMealId
        }
      });

      if (aliases.length > 0) {
        await this.request("/saved_meal_aliases", {
          method: "POST",
          body: aliases.map((alias) => ({ user_id: user.id, saved_meal_id: savedMealId, alias }))
        });
      }
      meal.aliases = aliases;
    } else {
      const refreshed = (await this.listSavedMeals(user)).find((savedMeal) => savedMeal.id === savedMealId);
      meal.aliases = refreshed?.aliases ?? [];
    }

    return meal;
  }

  async resolveSavedMeal(user: User, query: string): Promise<SavedMealResolution> {
    if (!query.trim()) throw badRequest('query is required.');
    const meals = await this.listSavedMeals(user);
    const trimmed = query.trim();
    const lowered = trimmed.toLowerCase();
    const normalized = normalizeMealQuery(trimmed);

    const exactName = meals.find((meal) => meal.name.toLowerCase() === lowered);
    if (exactName) return found('exact_name', 1, exactName);

    const exactAlias = meals.find((meal) => meal.aliases.some((alias) => alias.toLowerCase() === lowered));
    if (exactAlias) return found('exact_alias', 1, exactAlias);

    const normalizedName = meals.find((meal) => meal.normalized_name === normalized);
    if (normalizedName) return found('normalized_name', 1, normalizedName);

    const normalizedAlias = meals.find((meal) => meal.aliases.map(normalizeMealQuery).includes(normalized));
    if (normalizedAlias) return found('normalized_alias', 1, normalizedAlias);

    const candidates = meals.flatMap((meal) => [
      { meal, type: 'fuzzy_name' as const, score: similarity(normalized, meal.normalized_name) },
      ...meal.aliases.map((alias) => ({
        meal,
        type: 'fuzzy_alias' as const,
        score: similarity(normalized, normalizeMealQuery(alias))
      }))
    ]);
    candidates.sort((left, right) => right.score - left.score);
    const best = candidates[0];
    const second = candidates[1];
    if (best && best.score >= fuzzyThreshold && (!second || best.score - second.score >= 0.05 || second.meal.id === best.meal.id)) {
      return found(best.type, Number(best.score.toFixed(3)), best.meal);
    }

    return { match_status: 'not_found', message: 'No saved meal template found.' };
  }

  async logSavedMeal(user: User, savedMealId: string, input: LogSavedMealInput): Promise<FoodLog> {
    const meals = await this.listSavedMeals(user);
    const meal = meals.find((savedMeal) => savedMeal.id === savedMealId);
    if (!meal) throw badRequest('Saved meal not found.');

    const multiplier =
      input.serving_multiplier == null ? 1 : assertPositiveNumber(input.serving_multiplier, 'serving_multiplier');
    return this.createFoodLog(user, {
      ...scaleNutrition(meal, multiplier),
      logged_at: input.logged_at ?? nowIso(),
      meal_type: input.meal_type ?? meal.default_meal_type,
      label: meal.name,
      saved_meal_id: meal.id,
      serving_multiplier: multiplier,
      source: input.source ?? 'manual',
      raw_input: input.raw_input ?? null
    });
  }

  async deleteSavedMeal(user: User, savedMealId: string): Promise<void> {
    await this.request('/saved_meals', {
      method: 'DELETE',
      query: {
        id: `eq.${savedMealId}`,
        user_id: `eq.${user.id}`
      }
    });
  }

  async createWeightEntry(user: User, input: CreateWeightEntryInput): Promise<WeightEntry> {
    const rows = await this.request<WeightEntry[]>('/weight_entries', {
      method: 'POST',
      body: {
        user_id: user.id,
        measured_at: input.measured_at ?? nowIso(),
        weight_lb: assertPositiveNumber(input.weight_lb, 'weight_lb'),
        source: input.source
      },
      headers: { Prefer: 'return=representation' }
    });
    return rows[0];
  }

  async getWeightTrend(user: User, range: 'week' | 'month' | 'year'): Promise<WeightTrend> {
    const days = range === 'week' ? 7 : range === 'month' ? 30 : 365;
    const start = new Date();
    start.setUTCDate(start.getUTCDate() - days);
    const points = await this.request<WeightEntry[]>('/weight_entries', {
      query: {
        user_id: `eq.${user.id}`,
        measured_at: `gte.${start.toISOString()}`,
        order: 'measured_at.asc'
      }
    });
    const average =
      points.length === 0 ? null : points.reduce((total, point) => total + point.weight_lb, 0) / points.length;
    const change = points.length < 2 ? null : points[points.length - 1].weight_lb - points[0].weight_lb;
    return {
      range,
      points,
      average_weight_lb: average == null ? null : Number(average.toFixed(2)),
      change_lb: change == null ? null : Number(change.toFixed(2))
    };
  }

  async addAiAuditLog(user: User, input: Omit<AiAuditLog, 'id' | 'user_id' | 'created_at'>): Promise<AiAuditLog> {
    const rows = await this.request<AiAuditLog[]>('/ai_audit_log', {
      method: 'POST',
      body: { user_id: user.id, ...input },
      headers: { Prefer: 'return=representation' }
    });
    return rows[0];
  }

  async listAiAuditLogs(user: User): Promise<AiAuditLog[]> {
    return this.request<AiAuditLog[]>('/ai_audit_log', {
      query: {
        user_id: `eq.${user.id}`,
        order: 'created_at.asc'
      }
    });
  }

  private async request<T = unknown>(
    path: string,
    options: {
      method?: string;
      query?: Record<string, string | string[]>;
      body?: unknown;
      headers?: Record<string, string>;
    } = {}
  ): Promise<T> {
    const url = new URL(`/rest/v1${path}`, this.supabaseUrl);
    for (const [key, value] of Object.entries(options.query ?? {})) {
      if (Array.isArray(value)) {
        for (const item of value) url.searchParams.append(key, item);
      } else {
        url.searchParams.set(key, value);
      }
    }

    const response = await fetch(url, {
      method: options.method ?? 'GET',
      headers: {
        apikey: this.anonKey,
        Authorization: `Bearer ${this.bearerToken}`,
        'Content-Type': 'application/json',
        ...(options.headers ?? {})
      },
      body: options.body === undefined ? undefined : JSON.stringify(options.body)
    });

    if (!response.ok) {
      const text = await response.text();
      throw badRequest(text || `Supabase request failed with ${response.status}.`);
    }

    if (response.status === 204) return undefined as T;
    return (await response.json()) as T;
  }
}

export async function getSupabaseUser(supabaseUrl: string, anonKey: string, bearerToken: string): Promise<User> {
  const response = await fetch(new URL('/auth/v1/user', supabaseUrl), {
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${bearerToken}`
    }
  });
  if (!response.ok) throw badRequest('Unable to authenticate Supabase user.');
  const user = (await response.json()) as { id: string; email?: string | null };
  return { id: user.id, email: user.email ?? null };
}

function found(
  match_type: 'exact_name' | 'exact_alias' | 'normalized_name' | 'normalized_alias' | 'fuzzy_name' | 'fuzzy_alias',
  confidence: number,
  saved_meal: SavedMeal
): SavedMealResolution {
  return {
    match_status: 'found',
    match_type,
    confidence,
    saved_meal
  };
}
