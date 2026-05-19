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

  if (apnsResult.status === 200) {
    return { code: 200, device_key: deviceKey };
  }
  return {
    code: apnsResult.status >= 500 ? 500 : 400,
    message: apnsResult.reason ?? `apns status ${apnsResult.status}`,
    device_key: deviceKey,
  };
}
