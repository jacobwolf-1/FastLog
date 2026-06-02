import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import {
  HttpError,
  assertDate,
  badRequest,
  notFound,
  todayIsoDate,
  unauthorized,
  type AiProvider,
  type Source,
  type User
} from './domain.ts';
import { MemoryStore } from './memory-store.ts';
import { SupabaseStore, getSupabaseUser } from './supabase-store.ts';
import type { FastLogStore } from './store.ts';

type IntegrationProvider = Extract<AiProvider, 'chatgpt' | 'claude'>;

type AppOptions = {
  store?: FastLogStore;
  auth?: (request: IncomingMessage) => Promise<User>;
  integrationProvider?: IntegrationProvider | null;
};

const sharedMemoryStore = new MemoryStore();

export function createApp(options: AppOptions = {}) {
  return createServer(async (request, response) => {
    try {
      await handleRequest(request, response, options);
    } catch (error) {
      sendError(response, error);
    }
  });
}

async function handleRequest(request: IncomingMessage, response: ServerResponse, options: AppOptions) {
  setCors(response);
  if (request.method === 'OPTIONS') {
    response.writeHead(204);
    response.end();
    return;
  }

  const url = new URL(request.url ?? '/', `http://${request.headers.host ?? 'localhost'}`);
  const body = await readJson(request);
  const user = options.auth ? await options.auth(request) : await authenticate(request);
  const store = options.store ?? (await storeForRequest(request, user));
  const integrationProvider = integrationProviderFor(options);
  const trustedSource = sourceForIntegration(integrationProvider);
  const auditPayload = stripClientIntegrationMetadata(body);
  await store.ensureProfile(user);

  const method = request.method ?? 'GET';
  const path = url.pathname;

  if (method === 'POST' && path === '/v1/food-logs') {
    const created = await store.createFoodLog(user, { ...body, source: trustedSource });
    await auditIfAi(store, user, 'logFood', auditPayload, created, 'food_log', created.id, integrationProvider);
    return sendJson(response, 201, created);
  }


  const foodLogMatch = path.match(/^\/v1\/food-logs\/([^/]+)$/);
  if (method === "PATCH" && foodLogMatch) {
    const updated = await store.updateFoodLog(user, decodeURIComponent(foodLogMatch[1]), body);
    return sendJson(response, 200, updated);
  }

  if (method === "DELETE" && foodLogMatch) {
    await store.deleteFoodLog(user, decodeURIComponent(foodLogMatch[1]));
    return sendJson(response, 200, { deleted: true });
  }
  if (method === 'GET' && path === '/v1/food-logs') {
    const date = assertDate(requiredQuery(url, 'date'));
    return sendJson(response, 200, { food_logs: await store.listFoodLogs(user, date) });
  }

  if (method === 'GET' && path === '/v1/dashboard/today') {
    return sendJson(response, 200, await store.getDashboard(user, todayIsoDate()));
  }

  if (method === 'GET' && path === '/v1/dashboard') {
    const date = assertDate(requiredQuery(url, 'date'));
    return sendJson(response, 200, await store.getDashboard(user, date));
  }

  if (method === 'GET' && path === '/v1/targets/current') {
    return sendJson(response, 200, await store.getCurrentTargets(user, todayIsoDate()));
  }

  if (method === 'PATCH' && path === '/v1/targets') {
    const updated = await store.updateTargets(user, body);
    await auditIfAi(store, user, 'updateTargets', auditPayload, updated, 'daily_targets', updated.id, integrationProvider);
    return sendJson(response, 200, updated);
  }

  if (method === 'GET' && path === '/v1/saved-meals') {
    return sendJson(response, 200, { saved_meals: await store.listSavedMeals(user) });
  }

  if (method === 'GET' && path === '/v1/saved-meals/resolve') {
    return sendJson(response, 200, await store.resolveSavedMeal(user, requiredQuery(url, 'query')));
  }

  if (method === 'POST' && path === '/v1/saved-meals') {
    const created = await store.createSavedMeal(user, body);
    await auditIfAi(store, user, 'createSavedMeal', auditPayload, created, 'saved_meal', created.id, integrationProvider);
    return sendJson(response, 201, created);
  }

  const savedMealLogMatch = path.match(/^\/v1\/saved-meals\/([^/]+)\/log$/);
  if (method === 'POST' && savedMealLogMatch) {
    const created = await store.logSavedMeal(user, decodeURIComponent(savedMealLogMatch[1]), {
      ...body,
      source: trustedSource
    });
    await auditIfAi(store, user, 'logSavedMeal', auditPayload, created, 'food_log', created.id, integrationProvider);
    return sendJson(response, 201, created);
  }

  const savedMealDeleteMatch = path.match(/^\/v1\/saved-meals\/([^/]+)$/);

  if (method === "PATCH" && savedMealDeleteMatch) {
    const updated = await store.updateSavedMeal(user, decodeURIComponent(savedMealDeleteMatch[1]), body);
    return sendJson(response, 200, updated);
  }
  if (method === 'DELETE' && savedMealDeleteMatch) {
    await store.deleteSavedMeal(user, decodeURIComponent(savedMealDeleteMatch[1]));
    return sendJson(response, 200, { deleted: true });
  }

  if (method === 'POST' && path === '/v1/weight-entries') {
    return sendJson(response, 201, await store.createWeightEntry(user, body));
  }

  if (method === 'GET' && path === '/v1/weight-trend') {
    const range = requiredQuery(url, 'range');
    if (range !== 'week' && range !== 'month' && range !== 'year') throw badRequest('range must be week, month, or year.');
    return sendJson(response, 200, await store.getWeightTrend(user, range));
  }

  throw notFound();
}

async function authenticate(request: IncomingMessage): Promise<User> {
  const auth = request.headers.authorization;
  if (!auth?.startsWith('Bearer ')) throw unauthorized();
  const token = auth.slice('Bearer '.length);

  if ((process.env.FASTLOG_STORE ?? 'supabase') === 'memory') {
    if (!token.startsWith('dev:')) throw unauthorized('Memory mode expects Bearer dev:<user-id>[:email].');
    const [, id, email] = token.split(':');
    if (!id) throw unauthorized('Memory mode expects Bearer dev:<user-id>[:email].');
    return { id, email: email ?? null };
  }

  const supabaseUrl = requiredEnv('SUPABASE_URL');
  const anonKey = requiredEnv('SUPABASE_ANON_KEY');
  return getSupabaseUser(supabaseUrl, anonKey, token);
}

async function storeForRequest(request: IncomingMessage, user: User): Promise<FastLogStore> {
  if ((process.env.FASTLOG_STORE ?? 'supabase') === 'memory') return sharedMemoryStore;

  const auth = request.headers.authorization;
  if (!auth?.startsWith('Bearer ')) throw unauthorized();
  return new SupabaseStore(requiredEnv('SUPABASE_URL'), requiredEnv('SUPABASE_ANON_KEY'), auth.slice('Bearer '.length));
}

async function readJson(request: IncomingMessage): Promise<Record<string, any>> {
  if (request.method === 'GET' || request.method === 'DELETE' || request.method === 'OPTIONS') return {};
  const chunks: Buffer[] = [];
  for await (const chunk of request) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }
  if (chunks.length === 0) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function requiredQuery(url: URL, name: string): string {
  const value = url.searchParams.get(name);
  if (!value) throw badRequest(`${name} is required.`);
  return value;
}

function requiredEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function integrationProviderFor(options: AppOptions): IntegrationProvider | null {
  if (options.integrationProvider === 'chatgpt' || options.integrationProvider === 'claude') return options.integrationProvider;
  const envProvider = process.env.FASTLOG_INTEGRATION_PROVIDER;
  if (envProvider === 'chatgpt' || envProvider === 'claude') return envProvider;
  return null;
}

function sourceForIntegration(provider: IntegrationProvider | null): Source {
  return provider ?? 'manual';
}

function stripClientIntegrationMetadata(payload: Record<string, any>): Record<string, any> {
  const { provider: _provider, source: _source, ...safePayload } = payload;
  return safePayload;
}

async function auditIfAi(
  store: FastLogStore,
  user: User,
  action: string,
  requestPayload: unknown,
  responsePayload: unknown,
  createdResourceType: string,
  createdResourceId: string,
  provider: IntegrationProvider | null
) {
  if (!provider) return;
  const rawUserText =
    requestPayload && typeof requestPayload === 'object' && 'raw_input' in requestPayload
      ? String((requestPayload as Record<string, unknown>).raw_input ?? '')
      : null;
  await store.addAiAuditLog(user, {
    provider,
    action,
    raw_user_text: rawUserText || null,
    request_payload: requestPayload,
    response_payload: responsePayload,
    created_resource_type: createdResourceType,
    created_resource_id: createdResourceId
  });
}

function setCors(response: ServerResponse) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Authorization,Content-Type');
}

function sendJson(response: ServerResponse, status: number, body: unknown) {
  response.writeHead(status, { 'Content-Type': 'application/json' });
  response.end(JSON.stringify(body));
}

function sendError(response: ServerResponse, error: unknown) {
  if (error instanceof SyntaxError) return sendJson(response, 400, { error: 'Invalid JSON body.' });
  if (error instanceof HttpError) return sendJson(response, error.status, { error: error.message });
  const message = error instanceof Error ? error.message : 'Internal server error.';
  sendJson(response, 500, { error: message });
}
