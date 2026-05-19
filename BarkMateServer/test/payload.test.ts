import { describe, it, expect } from 'vitest';
import { buildPayload } from '../src/apns/payload';

describe('buildPayload', () => {
  it('builds an alert payload with title/subtitle/body', () => {
    const result = buildPayload({
      title: 'Hello',
      subtitle: 'sub',
      body: 'world',
    });
    expect(result.pushType).toBe('alert');
    const aps = result.payload.aps as Record<string, unknown>;
    expect(aps.alert).toEqual({ title: 'Hello', subtitle: 'sub', body: 'world' });
    expect(aps['mutable-content']).toBe(1);
    expect(aps.category).toBe('myNotificationCategory');
    expect(aps.sound).toBe('1107.caf'); // default sound
  });

  it('autoreplies "Empty Message" body when alert fields all empty', () => {
    const result = buildPayload({});
    const aps = result.payload.aps as Record<string, unknown>;
    expect((aps.alert as Record<string, unknown>).body).toBe('Empty Message');
  });

  it('appends .caf to sound name when missing', () => {
    const result = buildPayload({ body: 'x', sound: 'minuet' });
    const aps = result.payload.aps as Record<string, unknown>;
    expect(aps.sound).toBe('minuet.caf');
  });

  it('keeps .caf suffix as-is', () => {
    const result = buildPayload({ body: 'x', sound: 'silence.caf' });
    const aps = result.payload.aps as Record<string, unknown>;
    expect(aps.sound).toBe('silence.caf');
  });

  it('sets thread-id from group field', () => {
    const result = buildPayload({ body: 'x', group: 'work' });
    const aps = result.payload.aps as Record<string, unknown>;
    expect(aps['thread-id']).toBe('work');
  });

  it('builds background payload with content-available when delete=1', () => {
    const result = buildPayload({ delete: '1', title: 'ignored' });
    expect(result.pushType).toBe('background');
    const aps = result.payload.aps as Record<string, unknown>;
    expect(aps['content-available']).toBe(1);
    expect(aps.alert).toBeUndefined();
    expect(aps.sound).toBeUndefined();
  });

  it('places custom fields at root, lowercased, excluding internal keys', () => {
    const result = buildPayload({
      body: 'x',
      Url: 'https://example.com',
      IMAGE: 'https://img.example.com/a.png',
      ciphertext: 'enc-data',
      device_key: 'should-not-appear',
      device_token: 'should-not-appear-either',
    });
    expect(result.payload.url).toBe('https://example.com');
    expect(result.payload.image).toBe('https://img.example.com/a.png');
    expect(result.payload.ciphertext).toBe('enc-data');
    expect(result.payload.device_key).toBeUndefined();
    expect(result.payload.device_token).toBeUndefined();
  });

  it('captures id as collapseId', () => {
    const result = buildPayload({ body: 'x', id: 'msg-42' });
    expect(result.collapseId).toBe('msg-42');
    expect(result.payload.id).toBe('msg-42');
  });
});
