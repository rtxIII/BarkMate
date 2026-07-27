/**
 * Live Activity remote update route.
 *
 * The token in the path is ActivityKit's per-activity APNs token, not a Bark
 * device_key stored in KV.
 */

import { Hono, type Context } from 'hono';
import type { Bindings } from '../types';
import { failed, ok } from '../types';
import { getApnsJwt } from '../apns/jwt';
import { buildLiveActivityPayload, liveActivityTopic } from '../apns/liveactivity';
import { pushToApns } from '../apns/client';
import { DeviceStorage } from '../storage/kv';

type LiveActivityContext = Context<{ Bindings: Bindings }>;

const DELETED_TOKEN_SENTINEL = 'deleted';

export const liveActivityRoute = new Hono<{ Bindings: Bindings }>();

/**
 * Live Activity push-token 注册（自动 fan-out 的关联登记）。
 *
 * 客户端在拿到某个 Activity 的 `pushToken` 后上报：
 *   { device_key, aggregate_key, token }
 * server 以 `la:<device_key>:<aggregate_key>` 存储，`/push` 命中同 aggregateKey
 * 的 agent 状态推送时据此 fan-out 一条 ActivityKit 远程更新。
 * `token === "deleted"` 为注销哨兵（LA 结束时上报）。
 */
liveActivityRoute.post('/liveactivity/register', async (c) => {
  const raw = await readJsonBody(c);
  const deviceKey = pickField(raw, 'device_key');
  const aggregateKey = pickField(raw, 'aggregate_key');
  const token = pickField(raw, 'token');

  if (!deviceKey) return c.json(failed(400, 'device key is empty'), 400);
  if (!aggregateKey) return c.json(failed(400, 'aggregate key is empty'), 400);
  if (!token) return c.json(failed(400, 'token is empty'), 400);

  const storage = new DeviceStorage(c.env.DEVICES);

  // 关联登记前校验 device_key 已注册，避免悬空 LA token。
  const deviceToken = await storage.getDeviceToken(deviceKey);
  if (!deviceToken) return c.json(failed(400, 'device key not found'), 400);

  if (token === DELETED_TOKEN_SENTINEL) {
    await storage.deleteLiveActivityToken(deviceKey, aggregateKey);
  } else {
    await storage.saveLiveActivityToken(deviceKey, aggregateKey, token);
  }

  return c.json(ok({ device_key: deviceKey, aggregate_key: aggregateKey }));
});

liveActivityRoute.post('/liveactivity/:token', async (c) => {
  const activityToken = c.req.param('token').trim();
  if (!activityToken) return c.json(failed(400, 'activity token is empty'), 400);

  const raw = await readJsonBody(c);
  const built = buildLiveActivityPayload(raw);
  if ('error' in built) return c.json(failed(400, built.error), 400);

  if (!c.env.APNS_PRIVATE_KEY) {
    return c.json(failed(500, 'APNS_PRIVATE_KEY not configured'), 500);
  }

  const jwt = await getApnsJwt({
    privateKeyPem: c.env.APNS_PRIVATE_KEY,
    teamId: c.env.APNS_TEAM_ID,
    keyId: c.env.APNS_KEY_ID,
  });

  const apnsResult = await pushToApns({
    jwt,
    topic: liveActivityTopic(c.env.APNS_TOPIC),
    env: c.env.APNS_ENV,
    deviceToken: activityToken,
    payload: built.payload,
    pushType: 'liveactivity',
    priority: built.priority,
    ...(built.collapseId ? { collapseId: built.collapseId } : {}),
  });

  if (apnsResult.status === 200) return c.json(ok());

  return c.json(
    failed(
      apnsResult.status >= 500 ? 500 : 400,
      apnsResult.reason ?? `apns status ${apnsResult.status}`,
    ),
    apnsResult.status >= 500 ? 500 : 400,
  );
});

async function readJsonBody(c: LiveActivityContext): Promise<Record<string, unknown>> {
  try {
    const body = (await c.req.json()) as unknown;
    return isRecord(body) ? body : {};
  } catch {
    return {};
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function pickField(raw: Record<string, unknown>, key: string): string {
  const value = raw[key];
  return typeof value === 'string' ? value.trim() : '';
}
