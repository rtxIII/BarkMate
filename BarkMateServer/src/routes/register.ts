/**
 * 设备注册路由。完全兼容 bark-server `/register` 协议。
 * - POST /register             : JSON or form-urlencoded body
 * - GET  /register             : Legacy compat (query string)
 * - GET  /register/:device_key : 检查 key 有效性
 */

import { Hono, type Context } from 'hono';
import type { Bindings } from '../types';
import { failed, ok } from '../types';
import { DeviceStorage, isValidDeviceToken } from '../storage/kv';

type RegisterContext = Context<{ Bindings: Bindings }>;

const DELETED_TOKEN_SENTINEL = 'deleted';

export const registerRoute = new Hono<{ Bindings: Bindings }>();

registerRoute.post('/register', async (c) => {
  const params = await readBodyParams(c.req.raw);
  return handleRegister(c.env.DEVICES, params, c);
});

// Legacy compat: GET /register?devicetoken=...&key=...
registerRoute.get('/register', (c) => {
  const params = readQueryParams(c.req.raw);
  return handleRegister(c.env.DEVICES, params, c);
});

registerRoute.get('/register/:device_key', async (c) => {
  const deviceKey = c.req.param('device_key');
  if (!deviceKey) {
    return c.json(failed(400, 'device key is empty'), 400);
  }

  const storage = new DeviceStorage(c.env.DEVICES);
  const token = await storage.getDeviceToken(deviceKey);
  if (!token) {
    return c.json(failed(400, 'device key not found'), 400);
  }
  return c.json(ok());
});

// MARK: - Helpers

interface RegisterParams {
  deviceKey: string;
  deviceToken: string;
}

async function readBodyParams(request: Request): Promise<RegisterParams> {
  const contentType = (request.headers.get('content-type') ?? '').toLowerCase();
  let raw: Record<string, unknown> = {};

  if (contentType.includes('application/json')) {
    try {
      raw = (await request.clone().json()) as Record<string, unknown>;
    } catch {
      raw = {};
    }
  } else {
    const form = await request.clone().formData();
    for (const [key, value] of form.entries()) {
      raw[key] = typeof value === 'string' ? value : '';
    }
  }
  return normalize(raw);
}

function readQueryParams(request: Request): RegisterParams {
  const url = new URL(request.url);
  const raw: Record<string, unknown> = {};
  for (const [key, value] of url.searchParams.entries()) {
    raw[key] = value;
  }
  return normalize(raw);
}

function normalize(raw: Record<string, unknown>): RegisterParams {
  return {
    deviceKey: pickString(raw, ['device_key', 'key']),
    deviceToken: pickString(raw, ['device_token', 'devicetoken']),
  };
}

function pickString(raw: Record<string, unknown>, keys: string[]): string {
  for (const k of keys) {
    const v = raw[k];
    if (typeof v === 'string' && v.length > 0) return v;
  }
  return '';
}

async function handleRegister(
  kv: KVNamespace,
  params: RegisterParams,
  c: RegisterContext,
) {
  if (!isValidDeviceToken(params.deviceToken)) {
    return c.json(failed(400, 'device token is empty or invalid'), 400);
  }

  const storage = new DeviceStorage(kv);

  // 失效场景：客户端注销旧 key（bark-server 用 devicetoken=deleted 哨兵）
  if (params.deviceToken === DELETED_TOKEN_SENTINEL) {
    await storage.deleteDevice(params.deviceKey);
    return c.json(
      ok({
        key: params.deviceKey,
        device_key: params.deviceKey,
        device_token: DELETED_TOKEN_SENTINEL,
      }),
    );
  }

  const finalKey = await storage.saveDeviceToken(params.deviceKey, params.deviceToken);
  return c.json(
    ok({
      key: finalKey,
      device_key: finalKey,
      device_token: params.deviceToken,
    }),
  );
}
