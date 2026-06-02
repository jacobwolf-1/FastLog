import type {
  AiAuditLog,
  DailyTargets,
  FoodLog,
  SavedMeal,
  SavedMealResolution,
  User,
  WeightEntry
} from './domain.ts';

export type CreateFoodLogInput = {
  logged_at?: string | null;
  meal_type?: string | null;
  label?: string | null;
  calories: number;
  protein_g?: number | null;
  carbs_g?: number | null;
  fat_g?: number | null;
  fiber_g?: number | null;
  sodium_mg?: number | null;
  sugar_g?: number | null;
  potassium_mg?: number | null;
  saved_meal_id?: string | null;
  serving_multiplier?: number | null;
  source?: string | null;
  raw_input?: string | null;
};

export type UpdateTargetsInput = {
  calories: number;
  protein_g?: number | null;
  carbs_g?: number | null;
  fat_g?: number | null;
  fiber_g?: number | null;
  sodium_mg?: number | null;
  sugar_g?: number | null;
  potassium_mg?: number | null;
  effective_date?: string | null;
};

export type CreateSavedMealInput = {
  name: string;
  aliases?: string[];
  default_meal_type?: string | null;
  calories: number;
  protein_g?: number | null;
  carbs_g?: number | null;
  fat_g?: number | null;
  fiber_g?: number | null;
  sodium_mg?: number | null;
  sugar_g?: number | null;
  potassium_mg?: number | null;
};

export type LogSavedMealInput = {
  logged_at?: string | null;
  meal_type?: string | null;
  serving_multiplier?: number | null;
  source?: string | null;
  raw_input?: string | null;
};

export type CreateWeightEntryInput = {
  measured_at?: string | null;
  weight_lb: number;
  source: 'apple_health' | 'manual' | 'import';
};

export type WeightTrend = {
  range: 'week' | 'month' | 'year';
  points: WeightEntry[];
  average_weight_lb: number | null;
  change_lb: number | null;
};

export type Dashboard = {
  date: string;
  targets: DailyTargets | null;
  totals: Record<string, number>;
  remaining: Record<string, number>;
  logs: FoodLog[];
};

export interface FastLogStore {
  ensureProfile(user: User): Promise<void>;
  createFoodLog(user: User, input: CreateFoodLogInput): Promise<FoodLog>;
  listFoodLogs(user: User, date: string): Promise<FoodLog[]>;
  getDashboard(user: User, date: string): Promise<Dashboard>;
  getCurrentTargets(user: User, date: string): Promise<DailyTargets | null>;
  updateTargets(user: User, input: UpdateTargetsInput): Promise<DailyTargets>;
  listSavedMeals(user: User): Promise<SavedMeal[]>;
  createSavedMeal(user: User, input: CreateSavedMealInput): Promise<SavedMeal>;
  resolveSavedMeal(user: User, query: string): Promise<SavedMealResolution>;
  logSavedMeal(user: User, savedMealId: string, input: LogSavedMealInput): Promise<FoodLog>;
  deleteSavedMeal(user: User, savedMealId: string): Promise<void>;
  createWeightEntry(user: User, input: CreateWeightEntryInput): Promise<WeightEntry>;
  getWeightTrend(user: User, range: 'week' | 'month' | 'year'): Promise<WeightTrend>;
  addAiAuditLog(user: User, input: Omit<AiAuditLog, 'id' | 'user_id' | 'created_at'>): Promise<AiAuditLog>;
  listAiAuditLogs(user: User): Promise<AiAuditLog[]>;
}
