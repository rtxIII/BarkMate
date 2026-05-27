import { SELF } from 'cloudflare:test';
import { describe, it, expect } from 'vitest';
import app from '../src/index';

describe('GET /privacy', () => {
  it('returns 200 with text/html and bilingual content', async () => {
    const response = await SELF.fetch('http://localhost/privacy');
    expect(response.status).toBe(200);
    expect(response.headers.get('content-type') ?? '').toContain('text/html');

    const body = await response.text();
    expect(body).toContain('BarkMate Privacy Policy');
    expect(body).toContain('BarkMate 隐私政策');
    expect(body).toContain('group.com.barkmate.shared');
    expect(body).toContain('Apple');
    expect(body).toContain('Cloudflare');
    expect(body).toContain('AES');
  });
});

describe('GET /privacy.txt', () => {
  it('returns 200 with text/plain and key sections', async () => {
    const response = await SELF.fetch('http://localhost/privacy.txt');
    expect(response.status).toBe(200);
    expect(response.headers.get('content-type') ?? '').toContain('text/plain');

    const body = await response.text();
    expect(body).toContain('BarkMate Privacy Policy');
    expect(body).toContain('We do NOT collect');
    expect(body).toContain('DELETE /register/:device_key');
    expect(body).toContain('我们是谁');
    expect(body).toContain('不收集');
  });
});

describe('Privacy is public when bearer auth is enabled', () => {
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

  it('serves /privacy without authorization header', async () => {
    const response = await app.fetch(new Request('http://localhost/privacy'), authedEnv);
    expect(response.status).toBe(200);
  });

  it('serves /privacy.txt without authorization header', async () => {
    const response = await app.fetch(
      new Request('http://localhost/privacy.txt'),
      authedEnv,
    );
    expect(response.status).toBe(200);
  });
});

describe('GET /info advertises privacy-policy capability', () => {
  it('exposes privacy-policy in capabilities', async () => {
    const response = await SELF.fetch('http://localhost/info');
    const body = (await response.json()) as { data?: { capabilities: string[] } };
    expect(body.data?.capabilities).toContain('privacy-policy');
  });
});
