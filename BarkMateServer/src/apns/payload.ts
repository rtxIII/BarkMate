/**
 * APNs payload 构造。与 bark-server `apns/apns.go` 字段约定 1:1 兼容。
 *
 * Payload 顶层结构：
 * - `aps`: 系统字段（alert / sound / category / thread-id / mutable-content / content-available）
 * - 其它键：iOS NotificationServiceExtension 处理的自定义字段（url / image / icon / ...）
 *   全部小写化，与 Bark CiphertextProcessor 的 lowercase 归一逻辑保持一致。
 */

interface ApsAlert {
  title?: string;
  subtitle?: string;
  body?: string;
}

interface Aps {
  alert?: ApsAlert;
  sound?: string;
  category?: string;
  'thread-id'?: string;
  'content-available'?: 1;
  'mutable-content'?: 1;
}

export interface BuildPayloadResult {
  payload: Record<string, unknown>;
  pushType: 'alert' | 'background';
  collapseId: string | undefined;
}

/// 内部使用：在 push 处理前已经移除/不应进入 payload 的键。
const INTERNAL_KEYS = new Set([
  'device_key',
  'device_keys',
  'device_token',
  'devicetoken',
  'key',
  'aps',
]);

const SOUND_DEFAULT = '1107';

export function buildPayload(raw: Record<string, unknown>): BuildPayloadResult {
  const isSilent = String(raw['delete'] ?? '') === '1';
  const aps: Aps = { 'mutable-content': 1 };

  let title = pickString(raw, 'title');
  let subtitle = pickString(raw, 'subtitle');
  let body = pickString(raw, 'body');

  if (isSilent) {
    aps['content-available'] = 1;
  } else {
    if (title === undefined && subtitle === undefined && body === undefined) {
      body = 'Empty Message';
    }
    if (title !== undefined || subtitle !== undefined || body !== undefined) {
      const alert: ApsAlert = {};
      if (title !== undefined) alert.title = title;
      if (subtitle !== undefined) alert.subtitle = subtitle;
      if (body !== undefined) alert.body = body;
      aps.alert = alert;
    }

    const sound = pickString(raw, 'sound') ?? SOUND_DEFAULT;
    aps.sound = sound.endsWith('.caf') ? sound : `${sound}.caf`;

    aps.category = 'myNotificationCategory';

    const group = pickString(raw, 'group');
    if (group !== undefined) aps['thread-id'] = group;
  }

  const payload: Record<string, unknown> = { aps };
  for (const [k, v] of Object.entries(raw)) {
    const key = k.toLowerCase();
    if (INTERNAL_KEYS.has(key)) continue;
    payload[key] = typeof v === 'string' ? v : String(v);
  }

  return {
    payload,
    pushType: isSilent ? 'background' : 'alert',
    collapseId: pickString(raw, 'id'),
  };
}

function pickString(raw: Record<string, unknown>, key: string): string | undefined {
  const value = raw[key];
  if (typeof value !== 'string') return undefined;
  return value.length > 0 ? value : undefined;
}
