import { SELF, env } from 'cloudflare:test';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

interface PushResponse {
  code: number;
  message: string;
  data?: unknown;
}

const APNS_PRODUCTION_HOST = 'https://api.push.apple.com';
const TEST_DEVICE_KEY = 'test-key';
const TEST_DEVICE_TOKEN = 'aabbccdd11223344';

function mockApnsResponse(status: number, reason?: string): Response {
  const body = reason ? JSON.stringify({ reason }) : '';
  return new Response(body, { status });
}

beforeEach(async () => {
  const list = await env.DEVICES.list();
  for (const k of list.keys) await env.DEVICES.delete(k.name);
  await env.DEVICES.put(TEST_DEVICE_KEY, TEST_DEVICE_TOKEN);
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('POST /push (V2 JSON)', () => {
  it('200 success: forwards payload to APNs production host', async () => {
    let capturedUrl = '';
    let capturedHeaders: Headers | undefined;
    let capturedBody = '';
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
      capturedUrl = typeof input === 'string' ? input : (input as Request).url;
      capturedHeaders = new Headers(init?.headers ?? {});
      capturedBody = String(init?.body ?? '');
      return mockApnsResponse(200);
    });

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_key: TEST_DEVICE_KEY, body: 'Hello' }),
    });
    expect(response.status).toBe(200);
    const body = (await response.json()) as PushResponse;
    expect(body.code).toBe(200);

    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(capturedUrl).toBe(`${APNS_PRODUCTION_HOST}/3/device/${TEST_DEVICE_TOKEN}`);
    expect(capturedHeaders?.get('apns-topic')).toBe('com.barkagent.ios');
    expect(capturedHeaders?.get('apns-push-type')).toBe('alert');
    expect(capturedHeaders?.get('authorization')).toMatch(/^bearer ey/);

    const apnsPayload = JSON.parse(capturedBody) as Record<string, unknown>;
    const aps = apnsPayload.aps as Record<string, unknown>;
    expect((aps.alert as Record<string, unknown>).body).toBe('Hello');
    expect(aps['mutable-content']).toBe(1);
  });

  it('400 when device_key missing', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ body: 'no key' }),
    });
    expect(response.status).toBe(400);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('400 when device_key not in KV', async () => {
    vi.spyOn(globalThis, 'fetch'); // would be hit if the bug forwards, ensures none

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_key: 'not-registered', body: 'x' }),
    });
    expect(response.status).toBe(400);
    const body = (await response.json()) as PushResponse;
    expect(body.message).toContain('device token');
  });

  it('410 from APNs deletes the device key', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation(async () =>
      mockApnsResponse(410, 'Unregistered'),
    );

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_key: TEST_DEVICE_KEY, body: 'gone' }),
    });
    expect(response.status).toBe(400);

    const stored = await env.DEVICES.get(TEST_DEVICE_KEY);
    expect(stored).toBeNull();
  });

  it('400 BadDeviceToken from APNs deletes the device key', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation(async () =>
      mockApnsResponse(400, 'BadDeviceToken'),
    );

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_key: TEST_DEVICE_KEY, body: 'bad' }),
    });
    expect(response.status).toBe(400);
    expect(await env.DEVICES.get(TEST_DEVICE_KEY)).toBeNull();
  });

  it('batch push with device_keys array returns per-device results', async () => {
    await env.DEVICES.put('key2', 'token2');
    const fetchSpy = vi
      .spyOn(globalThis, 'fetch')
      .mockImplementation(async () => mockApnsResponse(200));

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_keys: [TEST_DEVICE_KEY, 'key2'],
        body: 'broadcast',
      }),
    });
    expect(response.status).toBe(200);
    const body = (await response.json()) as PushResponse & { data: Array<{ code: number }> };
    expect(body.data).toHaveLength(2);
    expect(body.data.every((r) => r.code === 200)).toBe(true);
    expect(fetchSpy).toHaveBeenCalledTimes(2);
  });
});

describe('Live Activity fan-out', () => {
  const AGG_KEY = 'demo-agent::task-1';
  const LA_TOKEN = 'la-push-token-001';
  const LA_KV_KEY = `la:${TEST_DEVICE_KEY}:${AGG_KEY}`;

  interface CapturedRequest {
    url: string;
    headers: Headers;
    body: string;
  }

  /// 按 APNs device-token 分流 alert / liveactivity 两条请求。
  function spyApnsByToken(): CapturedRequest[] {
    const captured: CapturedRequest[] = [];
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
      captured.push({
        url: typeof input === 'string' ? input : (input as Request).url,
        headers: new Headers(init?.headers ?? {}),
        body: String(init?.body ?? ''),
      });
      return mockApnsResponse(200);
    });
    return captured;
  }

  it('fans out an ActivityKit update when agent_status + LA token present', async () => {
    await env.DEVICES.put(LA_KV_KEY, LA_TOKEN);
    const captured = spyApnsByToken();

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_key: TEST_DEVICE_KEY,
        agent_id: 'demo-agent',
        task_id: 'task-1',
        agent_status: 'waiting_input',
        progress: '3/8',
        body: 'Confirm overwrite',
      }),
    });
    expect(response.status).toBe(200);

    const laReq = captured.find((r) => r.url.endsWith(`/3/device/${LA_TOKEN}`));
    expect(laReq).toBeDefined();
    expect(laReq?.headers.get('apns-push-type')).toBe('liveactivity');
    expect(laReq?.headers.get('apns-topic')).toBe('com.barkagent.ios.push-type.liveactivity');
    expect(laReq?.headers.get('apns-priority')).toBe('5');
    expect(laReq?.headers.get('apns-collapse-id')).toBe(AGG_KEY);

    const aps = (JSON.parse(laReq?.body ?? '{}') as { aps: Record<string, unknown> }).aps;
    expect(aps.event).toBe('update');
    expect(aps['content-state']).toEqual({
      status: 'waiting_input',
      stepTitle: 'Confirm overwrite',
      progress: '3/8',
    });

    // LA token 保留（update 不清理）。
    expect(await env.DEVICES.get(LA_KV_KEY)).toBe(LA_TOKEN);
  });

  it('sends event:end and clears the LA token on a terminal status', async () => {
    await env.DEVICES.put(LA_KV_KEY, LA_TOKEN);
    const captured = spyApnsByToken();

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_key: TEST_DEVICE_KEY,
        agent_id: 'demo-agent',
        task_id: 'task-1',
        agent_status: 'done',
        body: 'Turn complete',
      }),
    });
    expect(response.status).toBe(200);

    const laReq = captured.find((r) => r.url.endsWith(`/3/device/${LA_TOKEN}`));
    const aps = (JSON.parse(laReq?.body ?? '{}') as { aps: Record<string, unknown> }).aps;
    expect(aps.event).toBe('end');
    expect(laReq?.headers.get('apns-priority')).toBe('10');

    // 终态 → 清理登记。
    expect(await env.DEVICES.get(LA_KV_KEY)).toBeNull();
  });

  it('does not fan out when no LA token is registered', async () => {
    const captured = spyApnsByToken();

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        device_key: TEST_DEVICE_KEY,
        agent_id: 'demo-agent',
        task_id: 'task-1',
        agent_status: 'running',
        body: 'working',
      }),
    });
    expect(response.status).toBe(200);

    // 只有 alert 一条，无 liveactivity fan-out。
    expect(captured.some((r) => r.headers.get('apns-push-type') === 'liveactivity')).toBe(false);
  });

  it('does not fan out when agent_status is absent', async () => {
    await env.DEVICES.put(LA_KV_KEY, LA_TOKEN);
    const captured = spyApnsByToken();

    const response = await SELF.fetch('http://localhost/push', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_key: TEST_DEVICE_KEY, body: 'plain alert' }),
    });
    expect(response.status).toBe(200);

    expect(captured.some((r) => r.headers.get('apns-push-type') === 'liveactivity')).toBe(false);
    expect(await env.DEVICES.get(LA_KV_KEY)).toBe(LA_TOKEN);
  });
});

describe('JWT cache cleanup', () => {
  it('survives consecutive pushes (cache-or-resign)', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation(async () => mockApnsResponse(200));

    for (let i = 0; i < 3; i++) {
      const response = await SELF.fetch('http://localhost/push', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ device_key: TEST_DEVICE_KEY, body: `msg-${i}` }),
      });
      expect(response.status).toBe(200);
    }
  });
});

describe('V1 path-param compat', () => {
  it('GET /:device_key/:body sends alert with body from path', async () => {
    let capturedBody = '';
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (_input, init) => {
      capturedBody = String(init?.body ?? '');
      return mockApnsResponse(200);
    });

    const response = await SELF.fetch(
      `http://localhost/${TEST_DEVICE_KEY}/${encodeURIComponent('hi from path')}`,
    );
    expect(response.status).toBe(200);

    const apnsPayload = JSON.parse(capturedBody) as Record<string, unknown>;
    const alert = (apnsPayload.aps as Record<string, unknown>).alert as Record<string, unknown>;
    expect(alert.body).toBe('hi from path');
  });

  it('GET /:device_key/:title/:body uses both path params', async () => {
    let capturedBody = '';
    vi.spyOn(globalThis, 'fetch').mockImplementation(async (_input, init) => {
      capturedBody = String(init?.body ?? '');
      return mockApnsResponse(200);
    });

    const response = await SELF.fetch(
      `http://localhost/${TEST_DEVICE_KEY}/Greeting/${encodeURIComponent('hello world')}`,
    );
    expect(response.status).toBe(200);

    const apnsPayload = JSON.parse(capturedBody) as Record<string, unknown>;
    const alert = (apnsPayload.aps as Record<string, unknown>).alert as Record<string, unknown>;
    expect(alert.title).toBe('Greeting');
    expect(alert.body).toBe('hello world');
  });
});
