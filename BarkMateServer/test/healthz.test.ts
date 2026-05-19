import { SELF } from 'cloudflare:test';
import { describe, it, expect } from 'vitest';

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
