import { Hono } from 'hono';
import type { Bindings } from './types';
import { failed, ok } from './types';
import { registerRoute } from './routes/register';
import { pushRoute } from './routes/push';

const app = new Hono<{ Bindings: Bindings }>();

app.get('/healthz', (c) => c.json(ok({ status: 'ok' })));
app.get('/ping', (c) => c.json(ok(undefined, 'pong')));

app.route('/', registerRoute);
app.route('/', pushRoute);

app.onError((err, c) => {
  console.error('Unhandled error:', err);
  const message = err instanceof Error ? `${err.name}: ${err.message}` : String(err);
  return c.json(failed(500, message), 500);
});

export default app;
