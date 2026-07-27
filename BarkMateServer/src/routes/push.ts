/**
 * 推送路由 — 完全兼容 bark-server `/push` 协议。
 * - V2 JSON: POST /push (单推 + batch via device_keys)
 * - V1 路径参数兼容: /:device_key, /:device_key/:body, /:device_key/:title/:body,
 *   /:device_key/:title/:subtitle/:body （GET + POST 各 4 条路由）
 */

import { Hono, type Context } from 'hono';
import type { Bindings } from '../types';
import { failed, ok } from '../types';
import { DeviceStorage } from '../storage/kv';
import { getApnsJwt } from '../apns/jwt';
import { buildPayload } from '../apns/payload';
import { buildLiveActivityPayload, liveActivityTopic } from '../apns/liveactivity';
import { pushToApns, isInvalidToken } from '../apns/client';

type PushContext = Context<{ Bindings: Bindings }>;

export const pushRoute = new Hono<{ Bindings: Bindings }>();

pushRoute.post('/push', (c) => handle(c, readJsonBody));

const v1Paths = [
  '/:device_key',
  '/:device_key/:body',
  '/:device_key/:title/:body',
  '/:device_key/:title/:subtitle/:body',
] as const;

for (const path of v1Paths) {
  pushRoute.get(path, (c) => handle(c, readV1Params));
  pushRoute.post(path, (c) => handle(c, readV1Params));
}

// MARK: - Param parsing

type ParamReader = (c: PushContext) => Promise<Record<string, unknown>>;

async function readJsonBody(c: PushContext): Promise<Record<string, unknown>> {
  const raw: Record<string, unknown> = {};
  const ct = (c.req.header('content-type') ?? '').toLowerCase();
  if (ct.includes('application/json')) {
    try {
      Object.assign(raw, (await c.req.json()) as Record<string, unknown>);
    } catch {
      /* empty body */
    }
  } else {
    try {
      const form = await c.req.parseBody();
      Object.assign(raw, form);
    } catch {
      /* empty body */
    }
  }
  // query string overlay (medium priority)
  const url = new URL(c.req.url);
  for (const [k, v] of url.searchParams.entries()) raw[k] = v;
  return lowercaseKeys(raw);
}

async function readV1Params(c: PushContext): Promise<Record<string, unknown>> {
  const raw = await readJsonBody(c);
  // path params have highest priority
  const params = c.req.param() as Record<string, string>;
  for (const [k, v] of Object.entries(params)) {
    raw[k] = decodeURIComponent(v);
  }
  return raw;
}

function lowercaseKeys(raw: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(raw)) out[k.toLowerCase()] = v;
  return out;
}

// MARK: - Push orchestration

interface PerDeviceResult {
  code: number;
  message?: string;
  device_key: string;
}

async function handle(c: PushContext, reader: ParamReader) {
  const raw = await reader(c);
  const deviceKeys = extractDeviceKeys(raw);
  if (deviceKeys === null) {
    return c.json(failed(400, 'invalid device_keys field type'), 400);
  }
  delete raw.device_keys;

  // Batch path: device_keys present (even with single element) → array result
  if (deviceKeys.length > 0) {
    const results = await Promise.all(
      deviceKeys.map((key) => pushSingle(c.env, { ...raw, device_key: key })),
    );
    return c.json(ok(results));
  }

  // Single path: use device_key from raw (could be missing)
  const result = await pushSingle(c.env, raw);
  if (result.code !== 200) {
    return c.json(failed(result.code, result.message ?? 'push failed'), 400);
  }
  return c.json(ok());
}

function extractDeviceKeys(raw: Record<string, unknown>): string[] | null {
  const v = raw.device_keys;
  if (v === undefined || v === null) return [];
  if (typeof v === 'string') {
    return v
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);
  }
  if (Array.isArray(v)) return v.map((x) => String(x));
  return null;
}

async function pushSingle(env: Bindings, raw: Record<string, unknown>): Promise<PerDeviceResult> {
  const deviceKey = typeof raw.device_key === 'string' ? raw.device_key : '';
  if (!deviceKey) return { code: 400, message: 'device key is empty', device_key: '' };

  if (!env.APNS_PRIVATE_KEY) {
    return { code: 500, message: 'APNS_PRIVATE_KEY not configured', device_key: deviceKey };
  }

  const storage = new DeviceStorage(env.DEVICES);
  const deviceToken = await storage.getDeviceToken(deviceKey);
  if (!deviceToken) {
    return { code: 400, message: 'failed to get device token', device_key: deviceKey };
  }

  const { payload, pushType, collapseId } = buildPayload(raw);

  const jwt = await getApnsJwt({
    privateKeyPem: env.APNS_PRIVATE_KEY,
    teamId: env.APNS_TEAM_ID,
    keyId: env.APNS_KEY_ID,
  });

  const apnsResult = await pushToApns({
    jwt,
    topic: env.APNS_TOPIC,
    env: env.APNS_ENV,
    deviceToken,
    payload,
    pushType,
    ...(collapseId ? { collapseId } : {}),
  });

  if (isInvalidToken(apnsResult)) {
    await storage.deleteDevice(deviceKey);
  }

  // Best-effort Live Activity fan-out：仅当推送带 agent 状态、且该任务已登记 LA
  // push token 时，追发一条 ActivityKit 远程更新。失败不影响 alert 推送的返回码。
  await fanOutLiveActivity(env, storage, jwt, deviceKey, raw);

  if (apnsResult.status === 200) {
    return { code: 200, device_key: deviceKey };
  }
  return {
    code: apnsResult.status >= 500 ? 500 : 400,
    message: apnsResult.reason ?? `apns status ${apnsResult.status}`,
    device_key: deviceKey,
  };
}

// MARK: - Live Activity fan-out

/// done/failed 视为终态 → LA `end`；其余状态 → `update`。
const LA_END_STATUSES = new Set(['done', 'failed']);
const LA_KNOWN_STATUSES = new Set([
  'running',
  'waiting_input',
  'blocked',
  'done',
  'failed',
  'stale',
]);

/// 与 iOS `AgentTask.aggregateKey(agentID:taskID:)` 一致：`<agent_id>::<task_id-or-_>`。
function aggregateKeyFrom(raw: Record<string, unknown>): string | null {
  const agentID = pickRawString(raw, 'agent_id');
  if (!agentID) return null;
  const taskID = pickRawString(raw, 'task_id') || '_';
  return `${agentID}::${taskID}`;
}

async function fanOutLiveActivity(
  env: Bindings,
  storage: DeviceStorage,
  jwt: string,
  deviceKey: string,
  raw: Record<string, unknown>,
): Promise<void> {
  const status = pickRawString(raw, 'agent_status');
  if (!status || !LA_KNOWN_STATUSES.has(status)) return;

  const aggregateKey = aggregateKeyFrom(raw);
  if (!aggregateKey) return;

  const activityToken = await storage.getLiveActivityToken(deviceKey, aggregateKey);
  if (!activityToken) return;

  // content-state 与 iOS AgentActivityAttributes.ContentState 对齐（纯字符串）。
  const contentState: Record<string, unknown> = { status };
  const stepTitle = pickRawString(raw, 'body') ?? pickRawString(raw, 'title');
  contentState.stepTitle = stepTitle ?? '';
  const progress = pickRawString(raw, 'progress');
  if (progress) contentState.progress = progress;

  const isEnd = LA_END_STATUSES.has(status);
  const built = buildLiveActivityPayload({
    event: isEnd ? 'end' : 'update',
    content_state: contentState,
    // 终态推送优先级 10（立即送达并结束），进行中 5（省电节流）。
    priority: isEnd ? 10 : 5,
    collapse_id: aggregateKey,
  });
  if ('error' in built) return;

  try {
    const result = await pushToApns({
      jwt,
      topic: liveActivityTopic(env.APNS_TOPIC),
      env: env.APNS_ENV,
      deviceToken: activityToken,
      payload: built.payload,
      pushType: 'liveactivity',
      priority: built.priority,
      ...(built.collapseId ? { collapseId: built.collapseId } : {}),
    });
    // LA token 失效，或本条已 end → 清理登记，避免后续悬空 fan-out。
    if (isInvalidToken(result) || isEnd) {
      await storage.deleteLiveActivityToken(deviceKey, aggregateKey);
    }
  } catch {
    // best-effort：吞掉 fan-out 异常，绝不影响 alert 推送结果。
  }
}

function pickRawString(raw: Record<string, unknown>, key: string): string | undefined {
  const value = raw[key];
  if (typeof value !== 'string') return undefined;
  return value.length > 0 ? value : undefined;
}
