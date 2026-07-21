import { Hono } from 'hono';
import type { Bindings } from './types';
import { failed, ok } from './types';
import { registerRoute } from './routes/register';
import { pushRoute } from './routes/push';
import { liveActivityRoute } from './routes/liveactivity';
import { privacyRoute } from './routes/privacy';
import { installRoute } from './routes/install';
import { bearerAuth } from './auth';

const app = new Hono<{ Bindings: Bindings }>();

app.use('*', bearerAuth);
app.get('/healthz', (c) => c.json(ok({ status: 'ok' })));
app.get('/ping', (c) => c.json(ok(undefined, 'pong')));
app.get('/info', (c) =>
  c.json(
    ok({
      name: 'barkagent-server',
      version: '0.1.0',
      apns_env: c.env.APNS_ENV,
      apns_topic: c.env.APNS_TOPIC,
      auth_required: Boolean(c.env.BARKAGENT_AUTH_TOKEN),
      capabilities: ['register', 'push', 'v0.3-fields', 'health', 'privacy-policy', 'liveactivity', 'install-script', 'uninstall-script'],
    }),
  ),
);

app.route('/', privacyRoute);
app.route('/', installRoute);
app.route('/', registerRoute);
app.route('/', liveActivityRoute);
app.route('/', pushRoute);

app.onError((err, c) => {
  console.error('Unhandled error:', err);
  const message = err instanceof Error ? `${err.name}: ${err.message}` : String(err);
  return c.json(failed(500, message), 500);
});

export default app;
