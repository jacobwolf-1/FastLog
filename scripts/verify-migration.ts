import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const migrationPath = resolve('supabase/migrations/20260602120000_initial_schema.sql');
const sql = readFileSync(migrationPath, 'utf8');

const checks: Array<[string, boolean]> = [
  ['creates profiles', /create table public\.profiles/.test(sql)],
  ['enables RLS on food_logs', /alter table public\.food_logs enable row level security/.test(sql)],
  ['normalizes saved meal names', /normalize_meal_query/.test(sql)],
  ['aliases cascade when saved meal is deleted', /foreign key \(saved_meal_id, user_id\)[\s\S]+on delete cascade/.test(sql)],
  [
    'food logs preserve history when saved meal is deleted',
    /foreign key \(saved_meal_id, user_id\)[\s\S]+on delete set null \(saved_meal_id\)/.test(sql)
  ],
  [
    'food logs do not cascade delete from saved meals',
    !/constraint food_logs_saved_meal_user_fk[\s\S]+on delete cascade/.test(sql)
  ]
];

const failed = checks.filter(([, ok]) => !ok);
for (const [name, ok] of checks) {
  console.log(`${ok ? 'ok' : 'fail'} - ${name}`);
}

if (failed.length > 0) {
  process.exitCode = 1;
  throw new Error(`Migration static verification failed: ${failed.map(([name]) => name).join(', ')}`);
}

const supabaseCheck = spawnSync('supabase', ['--version'], { encoding: 'utf8' });
if (supabaseCheck.status !== 0) {
  console.log('skip - Supabase CLI not found; static migration verification completed.');
  process.exit(0);
}

console.log(`supabase - ${supabaseCheck.stdout.trim()}`);
console.log('note - Supabase CLI is available. Run `supabase db reset` in a disposable local project to apply from scratch.');
