/**
 * ActivityKit remote push payload.
 *
 * APNs requires push-type `liveactivity`, topic `<bundleID>.push-type.liveactivity`,
 * and an `aps` dictionary with timestamp, event, and content-state.
 */

type LiveActivityEvent = 'update' | 'end';
type LiveActivityPriority = 5 | 10;

interface LiveActivityAps {
  timestamp: number;
  event: LiveActivityEvent;
  'content-state': Record<string, unknown>;
  'stale-date'?: number;
  'dismissal-date'?: number;
  alert?: {
    title?: string;
    body?: string;
    sound?: string;
  };
}

export interface BuildLiveActivityPayloadResult {
  payload: Record<string, unknown>;
  priority: LiveActivityPriority;
  collapseId: string | undefined;
}

export type LiveActivityPayloadError =
  | 'invalid event'
  | 'content-state is required'
  | 'invalid priority';

export function buildLiveActivityPayload(
  raw: Record<string, unknown>,
  nowSeconds = Math.floor(Date.now() / 1000),
): BuildLiveActivityPayloadResult | { error: LiveActivityPayloadError } {
  const event = pickString(raw, 'event') ?? 'update';
  if (event !== 'update' && event !== 'end') return { error: 'invalid event' };

  const contentState = pickContentState(raw);
  if (contentState === undefined) return { error: 'content-state is required' };

  const priority = pickPriority(raw);
  if (priority === undefined) return { error: 'invalid priority' };

  const aps: LiveActivityAps = {
    timestamp: pickPositiveInteger(raw, 'timestamp') ?? nowSeconds,
    event,
    'content-state': contentState,
  };

  const staleDate = pickPositiveInteger(raw, 'stale_date') ?? pickPositiveInteger(raw, 'stale-date');
  if (staleDate !== undefined) aps['stale-date'] = staleDate;

  const dismissalDate =
    pickPositiveInteger(raw, 'dismissal_date') ?? pickPositiveInteger(raw, 'dismissal-date');
  if (dismissalDate !== undefined) aps['dismissal-date'] = dismissalDate;

  const alert = pickAlert(raw);
  if (alert !== undefined) aps.alert = alert;

  return {
    payload: { aps },
    priority,
    collapseId: pickString(raw, 'collapse_id') ?? pickString(raw, 'collapse-id'),
  };
}

export function liveActivityTopic(bundleTopic: string): string {
  return `${bundleTopic}.push-type.liveactivity`;
}

function pickContentState(raw: Record<string, unknown>): Record<string, unknown> | undefined {
  const value = raw['content-state'] ?? raw.content_state ?? raw.contentState;
  if (!isRecord(value)) return undefined;
  return value;
}

function pickAlert(
  raw: Record<string, unknown>,
): { title?: string; body?: string; sound?: string } | undefined {
  if (!isRecord(raw.alert)) return undefined;

  const title = pickString(raw.alert, 'title');
  const body = pickString(raw.alert, 'body');
  const sound = pickString(raw.alert, 'sound');
  if (title === undefined && body === undefined && sound === undefined) return undefined;

  return {
    ...(title !== undefined ? { title } : {}),
    ...(body !== undefined ? { body } : {}),
    ...(sound !== undefined ? { sound } : {}),
  };
}

function pickPriority(raw: Record<string, unknown>): LiveActivityPriority | undefined {
  const value = raw.priority;
  if (value === undefined || value === null || value === '') return 10;
  const numberValue = typeof value === 'number' ? value : Number(value);
  return numberValue === 5 || numberValue === 10 ? numberValue : undefined;
}

function pickPositiveInteger(raw: Record<string, unknown>, key: string): number | undefined {
  const value = raw[key];
  if (value === undefined || value === null || value === '') return undefined;
  const numberValue = typeof value === 'number' ? value : Number(value);
  if (!Number.isInteger(numberValue) || numberValue < 0) return undefined;
  return numberValue;
}

function pickString(raw: Record<string, unknown>, key: string): string | undefined {
  const value = raw[key];
  if (typeof value !== 'string') return undefined;
  return value.length > 0 ? value : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
