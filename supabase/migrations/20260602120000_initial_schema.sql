-- FastLog initial schema
-- Supabase service-role keys bypass RLS; never expose service-role credentials
-- to public clients, ChatGPT Actions, browsers, or iOS apps.

begin;

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

create or replace function public.normalize_meal_query(input text)
returns text
language sql
immutable
strict
as $$
  select regexp_replace(lower(input), '[^a-z0-9]+', '', 'g');
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update
    set email = excluded.email;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create table public.daily_targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  calories integer not null check (calories > 0),
  protein_g numeric check (protein_g is null or protein_g >= 0),
  carbs_g numeric check (carbs_g is null or carbs_g >= 0),
  fat_g numeric check (fat_g is null or fat_g >= 0),
  fiber_g numeric check (fiber_g is null or fiber_g >= 0),
  sodium_mg numeric check (sodium_mg is null or sodium_mg >= 0),
  sugar_g numeric check (sugar_g is null or sugar_g >= 0),
  potassium_mg numeric check (potassium_mg is null or potassium_mg >= 0),
  effective_date date not null,
  created_at timestamptz not null default now(),
  unique (user_id, effective_date)
);

create table public.saved_meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  normalized_name text generated always as (public.normalize_meal_query(name)) stored,
  default_meal_type text not null default 'unspecified'
    check (default_meal_type in ('breakfast', 'lunch', 'dinner', 'snack', 'unspecified')),
  calories integer not null check (calories > 0),
  protein_g numeric check (protein_g is null or protein_g >= 0),
  carbs_g numeric check (carbs_g is null or carbs_g >= 0),
  fat_g numeric check (fat_g is null or fat_g >= 0),
  fiber_g numeric check (fiber_g is null or fiber_g >= 0),
  sodium_mg numeric check (sodium_mg is null or sodium_mg >= 0),
  sugar_g numeric check (sugar_g is null or sugar_g >= 0),
  potassium_mg numeric check (potassium_mg is null or potassium_mg >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name),
  unique (user_id, normalized_name),
  unique (id, user_id)
);

create table public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  logged_at timestamptz not null,
  meal_type text not null default 'unspecified'
    check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack', 'unspecified')),
  label text,
  calories integer not null check (calories > 0),
  protein_g numeric check (protein_g is null or protein_g >= 0),
  carbs_g numeric check (carbs_g is null or carbs_g >= 0),
  fat_g numeric check (fat_g is null or fat_g >= 0),
  fiber_g numeric check (fiber_g is null or fiber_g >= 0),
  sodium_mg numeric check (sodium_mg is null or sodium_mg >= 0),
  sugar_g numeric check (sugar_g is null or sugar_g >= 0),
  potassium_mg numeric check (potassium_mg is null or potassium_mg >= 0),
  saved_meal_id uuid,
  serving_multiplier numeric not null default 1 check (serving_multiplier > 0),
  source text not null default 'manual'
    check (source in ('manual', 'shortcut', 'chatgpt', 'claude', 'import')),
  raw_input text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.saved_meal_aliases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  saved_meal_id uuid not null,
  alias text not null check (length(trim(alias)) > 0),
  normalized_alias text generated always as (public.normalize_meal_query(alias)) stored,
  created_at timestamptz not null default now(),
  unique (user_id, alias),
  unique (user_id, normalized_alias),
  foreign key (saved_meal_id, user_id)
    references public.saved_meals(id, user_id) on delete cascade
);

create table public.weight_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  measured_at timestamptz not null,
  weight_lb numeric not null check (weight_lb > 0),
  source text not null check (source in ('apple_health', 'manual', 'import')),
  created_at timestamptz not null default now()
);

create table public.ai_audit_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (provider in ('chatgpt', 'claude', 'other')),
  action text not null check (length(trim(action)) > 0),
  raw_user_text text,
  request_payload jsonb,
  response_payload jsonb,
  created_resource_type text,
  created_resource_id uuid,
  created_at timestamptz not null default now()
);

create index daily_targets_user_effective_date_idx
  on public.daily_targets (user_id, effective_date desc);

create index food_logs_user_logged_at_idx
  on public.food_logs (user_id, logged_at desc);

alter table public.food_logs
  add constraint food_logs_saved_meal_user_fk
  foreign key (saved_meal_id, user_id)
  references public.saved_meals(id, user_id)
  on delete set null (saved_meal_id);

create index food_logs_user_saved_meal_idx
  on public.food_logs (user_id, saved_meal_id)
  where saved_meal_id is not null;

create index saved_meals_user_normalized_name_idx
  on public.saved_meals (user_id, normalized_name);

create index saved_meals_normalized_name_trgm_idx
  on public.saved_meals using gin (normalized_name gin_trgm_ops);

create index saved_meal_aliases_user_normalized_alias_idx
  on public.saved_meal_aliases (user_id, normalized_alias);

create index saved_meal_aliases_normalized_alias_trgm_idx
  on public.saved_meal_aliases using gin (normalized_alias gin_trgm_ops);

create index weight_entries_user_measured_at_idx
  on public.weight_entries (user_id, measured_at desc);

create index ai_audit_log_user_created_at_idx
  on public.ai_audit_log (user_id, created_at desc);

create trigger food_logs_set_updated_at
before update on public.food_logs
for each row execute function public.set_updated_at();

create trigger saved_meals_set_updated_at
before update on public.saved_meals
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.daily_targets enable row level security;
alter table public.food_logs enable row level security;
alter table public.saved_meals enable row level security;
alter table public.saved_meal_aliases enable row level security;
alter table public.weight_entries enable row level security;
alter table public.ai_audit_log enable row level security;

create policy "profiles_select_own"
on public.profiles for select
using (id = auth.uid());

create policy "profiles_insert_own"
on public.profiles for insert
with check (id = auth.uid());

create policy "profiles_update_own"
on public.profiles for update
using (id = auth.uid())
with check (id = auth.uid());

create policy "daily_targets_select_own"
on public.daily_targets for select
using (user_id = auth.uid());

create policy "daily_targets_insert_own"
on public.daily_targets for insert
with check (user_id = auth.uid());

create policy "daily_targets_update_own"
on public.daily_targets for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "daily_targets_delete_own"
on public.daily_targets for delete
using (user_id = auth.uid());

create policy "food_logs_select_own"
on public.food_logs for select
using (user_id = auth.uid());

create policy "food_logs_insert_own"
on public.food_logs for insert
with check (user_id = auth.uid());

create policy "food_logs_update_own"
on public.food_logs for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "food_logs_delete_own"
on public.food_logs for delete
using (user_id = auth.uid());

create policy "saved_meals_select_own"
on public.saved_meals for select
using (user_id = auth.uid());

create policy "saved_meals_insert_own"
on public.saved_meals for insert
with check (user_id = auth.uid());

create policy "saved_meals_update_own"
on public.saved_meals for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "saved_meals_delete_own"
on public.saved_meals for delete
using (user_id = auth.uid());

create policy "saved_meal_aliases_select_own"
on public.saved_meal_aliases for select
using (user_id = auth.uid());

create policy "saved_meal_aliases_insert_own"
on public.saved_meal_aliases for insert
with check (user_id = auth.uid());

create policy "saved_meal_aliases_update_own"
on public.saved_meal_aliases for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "saved_meal_aliases_delete_own"
on public.saved_meal_aliases for delete
using (user_id = auth.uid());

create policy "weight_entries_select_own"
on public.weight_entries for select
using (user_id = auth.uid());

create policy "weight_entries_insert_own"
on public.weight_entries for insert
with check (user_id = auth.uid());

create policy "weight_entries_update_own"
on public.weight_entries for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

create policy "weight_entries_delete_own"
on public.weight_entries for delete
using (user_id = auth.uid());

create policy "ai_audit_log_select_own"
on public.ai_audit_log for select
using (user_id = auth.uid());

create policy "ai_audit_log_insert_own"
on public.ai_audit_log for insert
with check (user_id = auth.uid());

comment on table public.food_logs is
  'App-owned nutrition entries. HealthKit writes happen later from the iOS app, not directly from ChatGPT/Claude.';

comment on table public.saved_meals is
  'Reusable user-owned meal templates. AI assistants must resolve these through the backend before logging by name.';

comment on table public.ai_audit_log is
  'Append-only audit trail for AI-created operations. No user update/delete RLS policies are intentionally defined.';

commit;
