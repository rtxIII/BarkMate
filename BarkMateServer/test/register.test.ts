import { SELF, env } from 'cloudflare:test';
import { describe, it, expect, beforeEach } from 'vitest';

interface RegisterResponse {
  code: number;
  message: string;
  data?: {
    key?: string;
    device_key?: string;
    device_token?: string;
  };
}

async function clearDevicesKV() {
  const list = await env.DEVICES.list();
  for (const entry of list.keys) {
    await env.DEVICES.delete(entry.name);
  }
}

beforeEach(async () => {
  await clearDevicesKV();
});

describe('POST /register (JSON)', () => {
  it('creates new key when device_key omitted', async () => {
    const response = await SELF.fetch('http://localhost/register', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_token: 'aabbccdd' }),
    });
    expect(response.status).toBe(200);

    const body = (await response.json()) as RegisterResponse;
    expect(body.code).toBe(200);
    expect(body.data?.key).toBeTruthy();
    expect(body.data?.key?.length).toBe(22);
    expect(body.data?.device_token).toBe('aabbccdd');

    const stored = await env.DEVICES.get(body.data!.key!);
    expect(stored).toBe('aabbccdd');
  });

  it('updates existing key when both device_key and new device_token provided', async () => {
    await env.DEVICES.put('existing-key', 'old-token');

    const response = await SELF.fetch('http://localhost/register', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_key: 'existing-key', device_token: 'new-token' }),
    });
    expect(response.status).toBe(200);

    const body = (await response.json()) as RegisterResponse;
    expect(body.data?.key).toBe('existing-key');

    const stored = await env.DEVICES.get('existing-key');
    expect(stored).toBe('new-token');
  });

  it('accepts legacy "key" and "devicetoken" field names', async () => {
    const response = await SELF.fetch('http://localhost/register', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: 'devicetoken=legacy-token&key=legacy-key',
    });
    expect(response.status).toBe(200);

    const body = (await response.json()) as RegisterResponse;
    expect(body.data?.key).toBe('legacy-key');

    const stored = await env.DEVICES.get('legacy-key');
    expect(stored).toBe('legacy-token');
  });

  it('rejects empty device_token with 400', async () => {
    const response = await SELF.fetch('http://localhost/register', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_key: 'k' }),
    });
    expect(response.status).toBe(400);

    const body = (await response.json()) as RegisterResponse;
    expect(body.code).toBe(400);
    expect(body.message).toContain('device token');
  });

  it('treats devicetoken=deleted as a delete signal', async () => {
    await env.DEVICES.put('to-delete', 'some-token');

    const response = await SELF.fetch('http://localhost/register', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ device_key: 'to-delete', device_token: 'deleted' }),
    });
    expect(response.status).toBe(200);

    const stored = await env.DEVICES.get('to-delete');
    expect(stored).toBeNull();
  });
});

describe('GET /register (legacy compat)', () => {
  it('accepts query string params', async () => {
    const response = await SELF.fetch(
      'http://localhost/register?devicetoken=abc&key=qkey',
    );
    expect(response.status).toBe(200);

    const body = (await response.json()) as RegisterResponse;
    expect(body.data?.key).toBe('qkey');

    const stored = await env.DEVICES.get('qkey');
    expect(stored).toBe('abc');
  });
});

describe('GET /register/:device_key', () => {
  it('returns 200 when key exists', async () => {
    await env.DEVICES.put('present-key', 'token');

    const response = await SELF.fetch('http://localhost/register/present-key');
    expect(response.status).toBe(200);

    const body = (await response.json()) as RegisterResponse;
    expect(body.code).toBe(200);
  });

  it('returns 400 when key absent', async () => {
    const response = await SELF.fetch('http://localhost/register/missing-key');
    expect(response.status).toBe(400);

    const body = (await response.json()) as RegisterResponse;
    expect(body.code).toBe(400);
  });
});
