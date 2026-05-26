import { SELF } from 'cloudflare:test';
import { describe, it, expect } from 'vitest';
import app from '../src/index';

describe('GET /healthz', () => {
  it('returns 200 with code=200 and data.status=ok', async () => {
    const response = await SELF.fetch('http://localhost/healthz');
    expect(response.status).toBe(200);

    const body = (await response.json()) as {
      code: number;
      message: string;
      data?: { status: string };
    };
    expect(body.code).toBe(200);
    expect(body.data?.status).toBe('ok');
  });
});

describe('GET /ping', () => {
  it('returns 200 with message=pong', async () => {
    const response = await SELF.fetch('http://localhost/ping');
    expect(response.status).toBe(200);

    const body = (await response.json()) as { code: number; message: string };
    expect(body.code).toBe(200);
    expect(body.message).toBe('pong');
  });
});

describe('GET /info', () => {
  it('returns server capabilities without requiring auth', async () => {
    const response = await SELF.fetch('http://localhost/info');
    expect(response.status).toBe(200);

    const body = (await response.json()) as {
      code: number;
      data?: {
        name: string;
        capabilities: string[];
        auth_required: boolean;
      };
    };
    expect(body.code).toBe(200);
    expect(body.data?.name).toBe('barkmate-server');
    expect(body.data?.capabilities).toContain('v0.3-fields');
    expect(body.data?.capabilities).toContain('health');
    expect(body.data?.auth_required).toBe(false);
  });
});

describe('Bearer auth', () => {
  const authedEnv = {
    DEVICES: {
      get: async () => null,
      put: async () => undefined,
      delete: async () => undefined,
      list: async () => ({ keys: [], list_complete: true, cacheStatus: null }),
    } as unknown as KVNamespace,
    APNS_TEAM_ID: 'TEAM',
    APNS_KEY_ID: 'KEY',
    APNS_TOPIC: 'com.barkmate.ios',
    APNS_ENV: 'sandbox' as const,
    APNS_PRIVATE_KEY: 'unused',
    BARKMATE_AUTH_TOKEN: 'secret',
  };

  it('rejects protected routes when token is configured and missing', async () => {
    const response = await app.fetch(
      new Request('http://localhost/register/test-key'),
      authedEnv,
    );
    expect(response.status).toBe(401);
  });

  it('allows protected routes with a matching bearer token', async () => {
    const response = await app.fetch(
      new Request('http://localhost/register/test-key', {
        headers: { authorization: 'Bearer secret' },
      }),
      authedEnv,
    );
    expect(response.status).toBe(400);
  });

  it('keeps health routes public when token is configured', async () => {
    const response = await app.fetch(new Request('http://localhost/info'), authedEnv);
    expect(response.status).toBe(200);

    const body = (await response.json()) as { data?: { auth_required: boolean } };
    expect(body.data?.auth_required).toBe(true);
  });
});
