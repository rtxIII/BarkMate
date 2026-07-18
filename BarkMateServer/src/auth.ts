import type { MiddlewareHandler } from 'hono';
import type { Bindings } from './types';
import { failed } from './types';

type AppEnv = { Bindings: Bindings };

const PUBLIC_PATHS = new Set([
  '/healthz',
  '/ping',
  '/info',
  '/privacy',
  '/privacy.txt',
  '/install.sh',
  '/docs/cli-setup',
  '/docs/cli-setup.md',
]);

export const bearerAuth: MiddlewareHandler<AppEnv> = async (c, next) => {
  const token = c.env.BARKAGENT_AUTH_TOKEN;
  if (!token || PUBLIC_PATHS.has(new URL(c.req.url).pathname)) {
    await next();
    return;
  }

  const header = c.req.header('authorization') ?? '';
  const expected = `Bearer ${token}`;
  if (header !== expected) {
    return c.json(failed(401, 'unauthorized'), 401);
  }

  await next();
};

