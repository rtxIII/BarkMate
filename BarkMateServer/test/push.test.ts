import { SELF, env } from 'cloudflare:test';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';

interface PushResponse {
  code: number;
  message: string;
  data?: unknown;
}

const APNS_SANDBOX_HOST = 'https://api.sandbox.push.apple.com';
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
  it('200 success: forwards payload to APNs sandbox host', async () => {
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
    expect(capturedUrl).toBe(`${APNS_SANDBOX_HOST}/3/device/${TEST_DEVICE_TOKEN}`);
    expect(capturedHeaders?.get('apns-topic')).toBe('com.barkmate.ios');
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

