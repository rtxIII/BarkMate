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

type LiveActivityContext = Context<{ Bindings: Bindings }>;

export const liveActivityRoute = new Hono<{ Bindings: Bindings }>();

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
