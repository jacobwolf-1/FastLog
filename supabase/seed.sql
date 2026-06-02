-- Development seed data.
-- Create at least one local Supabase Auth user before running this file.
-- The seed attaches demo targets, meals, logs, and weight entries to the
-- first auth user found.

begin;

do $$
declare
  seed_user_id uuid;
  seed_email text;
  gb_potato_id uuid;
begin
  select id, email
  into seed_user_id, seed_email
  from auth.users
  order by created_at
  limit 1;

  if seed_user_id is null then
    raise exception 'No auth.users row found. Create a local Supabase Auth user before running seed.sql.';
  end if;

  insert into public.profiles (id, email)
  values (seed_user_id, coalesce(seed_email, 'demo@fastlog.local'))
  on conflict (id) do update
    set email = excluded.email;

  insert into public.daily_targets (
    user_id,
    calories,
    protein_g,
    carbs_g,
    fat_g,
    fiber_g,
    sodium_mg,
    sugar_g,
    potassium_mg,
    effective_date
  )
  values (
    seed_user_id,
    2300,
    180,
    220,
    70,
    35,
    2300,
    75,
    4700,
    current_date
  )
  on conflict (user_id, effective_date) do update
    set calories = excluded.calories,
        protein_g = excluded.protein_g,
        carbs_g = excluded.carbs_g,
        fat_g = excluded.fat_g,
        fiber_g = excluded.fiber_g,
        sodium_mg = excluded.sodium_mg,
        sugar_g = excluded.sugar_g,
        potassium_mg = excluded.potassium_mg;

  insert into public.saved_meals (
    user_id,
    name,
    default_meal_type,
    calories,
    protein_g,
    carbs_g,
    fat_g,
    fiber_g,
    sodium_mg
  )
  values (
    seed_user_id,
    'GB + Potato',
    'unspecified',
    610,
    50,
    56,
    18,
    5,
    850
  )
  on conflict (user_id, normalized_name) do update
    set calories = excluded.calories,
        protein_g = excluded.protein_g,
        carbs_g = excluded.carbs_g,
        fat_g = excluded.fat_g,
        fiber_g = excluded.fiber_g,
        sodium_mg = excluded.sodium_mg
  returning id into gb_potato_id;

  insert into public.saved_meal_aliases (user_id, saved_meal_id, alias)
  values
    (seed_user_id, gb_potato_id, 'ground beef potato'),
    (seed_user_id, gb_potato_id, 'beef potato'),
    (seed_user_id, gb_potato_id, 'gb potato')
  on conflict (user_id, normalized_alias) do nothing;

  insert into public.food_logs (
    user_id,
    logged_at,
    meal_type,
    label,
    calories,
    protein_g,
    carbs_g,
    fat_g,
    fiber_g,
    sodium_mg,
    saved_meal_id,
    serving_multiplier,
    source,
    raw_input
  )
  values (
    seed_user_id,
    now(),
    'lunch',
    'GB + Potato',
    610,
    50,
    56,
    18,
    5,
    850,
    gb_potato_id,
    1,
    'chatgpt',
    'Log GB + Potato for lunch'
  );

  insert into public.weight_entries (user_id, measured_at, weight_lb, source)
  values (seed_user_id, now(), 178.4, 'manual');
end $$;

commit;
