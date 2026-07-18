import { SELF } from 'cloudflare:test';
import { describe, it, expect, afterEach, vi } from 'vitest';
import { buildLiveActivityPayload, liveActivityTopic } from '../src/apns/liveactivity';

const APNS_PRODUCTION_HOST = 'https://api.push.apple.com';
const TEST_ACTIVITY_TOKEN = 'live-token-001';

function mockApnsResponse(status: number, reason?: string): Response {
  const body = reason ? JSON.stringify({ reason }) : '';
  return new Response(body, { status });
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe('buildLiveActivityPayload', () => {
  it('builds an ActivityKit update payload', () => {
    const result = buildLiveActivityPayload(
      {
        event: 'update',
        content_state: {
          status: 'running',
          progress: '3/8',
        },
        stale_date: 1_800,
        priority: 5,
        collapse_id: 'agent-task-42',
      },
      1_000,
    );

    expect('error' in result).toBe(false);
    if ('error' in result) return;

    expect(result.priority).toBe(5);
    expect(result.collapseId).toBe('agent-task-42');
    expect(result.payload).toEqual({
      aps: {
        timestamp: 1_000,
        event: 'update',
        'content-state': {
          status: 'running',
          progress: '3/8',
        },
        'stale-date': 1_800,
      },
    });
  });

  it('requires content-state and update/end event', () => {
    expect(buildLiveActivityPayload({ event: 'start', content_state: {} })).toEqual({
      error: 'invalid event',
    });
    expect(buildLiveActivityPayload({ event: 'update' })).toEqual({
      error: 'content-state is required',
    });
  });

  it('formats the liveactivity topic from bundle topic', () => {
    expect(liveActivityTopic('com.barkagent.ios')).toBe(
      'com.barkagent.ios.push-type.liveactivity',
    );
  });
});

describe('POST /liveactivity/:token', () => {
  it('forwards an ActivityKit update to APNs', async () => {
    let capturedUrl = '';
    let capturedHeaders: Headers | undefined;
    let capturedBody = '';

    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockImplementation(async (input, init) => {
      capturedUrl = typeof input === 'string' ? input : (input as Request).url;
      capturedHeaders = new Headers(init?.headers ?? {});
      capturedBody = String(init?.body ?? '');
      return mockApnsResponse(200);
    });

    const response = await SELF.fetch(`http://localhost/liveactivity/${TEST_ACTIVITY_TOKEN}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        event: 'update',
        content_state: {
          status: 'running',
          progress: '4/8',
          eta: '2026-06-04T12:00:00Z',
        },
        priority: 10,
        collapse_id: 'demo-agent::task-1',
      }),
    });

    expect(response.status).toBe(200);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    expect(capturedUrl).toBe(`${APNS_PRODUCTION_HOST}/3/device/${TEST_ACTIVITY_TOKEN}`);
    expect(capturedHeaders?.get('apns-topic')).toBe(
      'com.barkagent.ios.push-type.liveactivity',
    );
    expect(capturedHeaders?.get('apns-push-type')).toBe('liveactivity');
    expect(capturedHeaders?.get('apns-priority')).toBe('10');
    expect(capturedHeaders?.get('apns-collapse-id')).toBe('demo-agent::task-1');

    const payload = JSON.parse(capturedBody) as { aps: Record<string, unknown> };
    expect(payload.aps.event).toBe('update');
    expect(payload.aps.timestamp).toEqual(expect.any(Number));
    expect(payload.aps['content-state']).toEqual({
      status: 'running',
      progress: '4/8',
      eta: '2026-06-04T12:00:00Z',
    });
  });

  it('returns 400 without forwarding when content-state is missing', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch');

    const response = await SELF.fetch(`http://localhost/liveactivity/${TEST_ACTIVITY_TOKEN}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ event: 'update' }),
    });

    expect(response.status).toBe(400);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('returns APNs errors with a compatible error body', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation(async () =>
      mockApnsResponse(400, 'BadDeviceToken'),
    );

    const response = await SELF.fetch(`http://localhost/liveactivity/${TEST_ACTIVITY_TOKEN}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        event: 'end',
        content_state: { status: 'done', progress: '8/8' },
      }),
    });

    expect(response.status).toBe(400);
    const body = (await response.json()) as { code: number; message: string };
    expect(body.code).toBe(400);
    expect(body.message).toBe('BadDeviceToken');
  });
});
