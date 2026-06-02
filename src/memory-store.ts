import {
  assertDate,
  assertMealType,
  assertNonNegativeOptional,
  assertPositiveNumber,
  assertSource,
  badRequest,
  id,
  isoDateFromTimestamp,
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

export class MemoryStore implements FastLogStore {
  profiles = new Map<string, User>();
  targets: DailyTargets[] = [];
  foodLogs: FoodLog[] = [];
  savedMeals: SavedMeal[] = [];
  weightEntries: WeightEntry[] = [];
  aiAuditLogs: AiAuditLog[] = [];

  async ensureProfile(user: User): Promise<void> {
    this.profiles.set(user.id, user);
  }

  async createFoodLog(user: User, input: CreateFoodLogInput): Promise<FoodLog> {
    const nutrition = parseNutrition(input as Record<string, unknown>);
    const savedMealId = input.saved_meal_id ?? null;

    if (savedMealId) {
      const savedMeal = this.savedMeals.find((meal) => meal.id === savedMealId && meal.user_id === user.id);
      if (!savedMeal) throw badRequest('saved_meal_id must reference one of the authenticated user saved meals.');
    }

    const timestamp = nowIso();
    const log: FoodLog = {
      id: id(),
      user_id: user.id,
      logged_at: input.logged_at ?? timestamp,
      meal_type: assertMealType(input.meal_type),
      label: input.label ?? null,
      ...nutrition,
      saved_meal_id: savedMealId,
      serving_multiplier:
        input.serving_multiplier == null ? 1 : assertPositiveNumber(input.serving_multiplier, 'serving_multiplier'),
      source: assertSource(input.source),
      raw_input: input.raw_input ?? null,
      created_at: timestamp,
      updated_at: timestamp
    };

    this.foodLogs.push(log);
    return log;
  }



  async updateFoodLog(user: User, foodLogId: string, input: UpdateFoodLogInput): Promise<FoodLog> {
    const log = this.foodLogs.find((foodLog) => foodLog.id === foodLogId && foodLog.user_id === user.id);
    if (!log) throw badRequest('Food log not found.');

    const patch: Partial<FoodLog> = { ...parseNutritionPatch(input as Record<string, unknown>) };
    if ('logged_at' in input) patch.logged_at = input.logged_at ?? log.logged_at;
    if ('meal_type' in input) patch.meal_type = assertMealType(input.meal_type);
    if ('label' in input) patch.label = input.label ?? null;
    if ('raw_input' in input) patch.raw_input = input.raw_input ?? null;

    Object.assign(log, patch, { updated_at: nowIso() });
    return log;
  }

  async deleteFoodLog(user: User, foodLogId: string): Promise<void> {
    const before = this.foodLogs.length;
    this.foodLogs = this.foodLogs.filter((foodLog) => !(foodLog.id === foodLogId && foodLog.user_id === user.id));
    if (this.foodLogs.length === before) throw badRequest('Food log not found.');
  }

  async listFoodLogs(user: User, date: string): Promise<FoodLog[]> {
    assertDate(date);
    return this.foodLogs
      .filter((log) => log.user_id === user.id && isoDateFromTimestamp(log.logged_at) === date)
      .sort((left, right) => left.logged_at.localeCompare(right.logged_at));
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
    return (
      this.targets
        .filter((target) => target.user_id === user.id && target.effective_date <= date)
        .sort((left, right) => right.effective_date.localeCompare(left.effective_date))[0] ?? null
    );
  }

  async updateTargets(user: User, input: UpdateTargetsInput): Promise<DailyTargets> {
    const nutrition = parseNutrition(input as Record<string, unknown>);
    const effectiveDate = assertDate(input.effective_date ?? todayIsoDate());
    const existing = this.targets.find((target) => target.user_id === user.id && target.effective_date === effectiveDate);

    if (existing) {
      Object.assign(existing, nutrition);
      return existing;
    }

    const target: DailyTargets = {
      id: id(),
      user_id: user.id,
      ...nutrition,
      effective_date: effectiveDate,
      created_at: nowIso()
    };
    this.targets.push(target);
    return target;
  }

  async listSavedMeals(user: User): Promise<SavedMeal[]> {
    return this.savedMeals
      .filter((meal) => meal.user_id === user.id)
      .sort((left, right) => left.name.localeCompare(right.name));
  }

  async createSavedMeal(user: User, input: CreateSavedMealInput): Promise<SavedMeal> {
    if (!input.name || !input.name.trim()) throw badRequest('name is required.');
    const normalizedName = normalizeMealQuery(input.name);
    const aliases = [...new Set((input.aliases ?? []).map((alias) => alias.trim()).filter(Boolean))];
    const normalizedAliases = aliases.map(normalizeMealQuery);

    if (this.savedMeals.some((meal) => meal.user_id === user.id && meal.normalized_name === normalizedName)) {
      throw badRequest('A saved meal with this name already exists.');
    }
    for (const aliasKey of normalizedAliases) {
      if (this.savedMeals.some((meal) => meal.user_id === user.id && meal.aliases.map(normalizeMealQuery).includes(aliasKey))) {
        throw badRequest('A saved meal alias already exists.');
      }
    }

    const timestamp = nowIso();
    const meal: SavedMeal = {
      id: id(),
      user_id: user.id,
      name: input.name.trim(),
      normalized_name: normalizedName,
      default_meal_type: assertMealType(input.default_meal_type),
      ...parseNutrition(input as Record<string, unknown>),
      aliases,
      created_at: timestamp,
      updated_at: timestamp
    };
    this.savedMeals.push(meal);
    return meal;
  }



  async updateSavedMeal(user: User, savedMealId: string, input: UpdateSavedMealInput): Promise<SavedMeal> {
    const meal = this.savedMeals.find((savedMeal) => savedMeal.id === savedMealId && savedMeal.user_id === user.id);
    if (!meal) throw badRequest('Saved meal not found.');

    if ('name' in input) {
      if (!input.name || !input.name.trim()) throw badRequest('name cannot be blank.');
      const normalizedName = normalizeMealQuery(input.name);
      if (this.savedMeals.some((savedMeal) => savedMeal.user_id === user.id && savedMeal.id !== savedMealId && savedMeal.normalized_name === normalizedName)) {
        throw badRequest('A saved meal with this name already exists.');
      }
      meal.name = input.name.trim();
      meal.normalized_name = normalizedName;
    }

    if ('default_meal_type' in input) meal.default_meal_type = assertMealType(input.default_meal_type);
    Object.assign(meal, parseNutritionPatch(input as Record<string, unknown>));

    if ('aliases' in input) {
      const aliases = [...new Set((input.aliases ?? []).map((alias) => alias.trim()).filter(Boolean))];
      const normalizedAliases = aliases.map(normalizeMealQuery);
      if (new Set(normalizedAliases).size !== normalizedAliases.length) throw badRequest('Duplicate aliases are not allowed.');

      for (const aliasKey of normalizedAliases) {
        const conflict = this.savedMeals.some((savedMeal) =>
          savedMeal.user_id === user.id &&
          savedMeal.id !== savedMealId &&
          savedMeal.aliases.map(normalizeMealQuery).includes(aliasKey)
        );
        if (conflict) throw badRequest('A saved meal alias already exists.');
      }
      meal.aliases = aliases;
    }

    meal.updated_at = nowIso();
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
    const meal = this.savedMeals.find((savedMeal) => savedMeal.user_id === user.id && savedMeal.id === savedMealId);
    if (!meal) throw badRequest('Saved meal not found.');

    const multiplier =
      input.serving_multiplier == null ? 1 : assertPositiveNumber(input.serving_multiplier, 'serving_multiplier');
    const nutrition = scaleNutrition(meal, multiplier);

    return this.createFoodLog(user, {
      ...nutrition,
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
    const meal = this.savedMeals.find((savedMeal) => savedMeal.id === savedMealId && savedMeal.user_id === user.id);
    if (!meal) throw badRequest('Saved meal not found.');

    this.savedMeals = this.savedMeals.filter((savedMeal) => savedMeal.id !== savedMealId);
    for (const log of this.foodLogs) {
      if (log.user_id === user.id && log.saved_meal_id === savedMealId) {
        log.saved_meal_id = null;
        log.updated_at = nowIso();
      }
    }
  }

  async createWeightEntry(user: User, input: CreateWeightEntryInput): Promise<WeightEntry> {
    const source = input.source;
    if (source !== 'apple_health' && source !== 'manual' && source !== 'import') throw badRequest('Invalid weight source.');

    const entry: WeightEntry = {
      id: id(),
      user_id: user.id,
      measured_at: input.measured_at ?? nowIso(),
      weight_lb: assertPositiveNumber(input.weight_lb, 'weight_lb'),
      source,
      created_at: nowIso()
    };
    this.weightEntries.push(entry);
    return entry;
  }

  async getWeightTrend(user: User, range: 'week' | 'month' | 'year'): Promise<WeightTrend> {
    const days = range === 'week' ? 7 : range === 'month' ? 30 : 365;
    const start = new Date();
    start.setUTCDate(start.getUTCDate() - days);

    const points = this.weightEntries
      .filter((entry) => entry.user_id === user.id && new Date(entry.measured_at) >= start)
      .sort((left, right) => left.measured_at.localeCompare(right.measured_at));

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
    const log: AiAuditLog = {
      id: id(),
      user_id: user.id,
      ...input,
      created_at: nowIso()
    };
    this.aiAuditLogs.push(log);
    return log;
  }

  async listAiAuditLogs(user: User): Promise<AiAuditLog[]> {
    return this.aiAuditLogs.filter((log) => log.user_id === user.id);
  }
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
