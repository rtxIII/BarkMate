/**
 * APNs HTTP/2 推送客户端。Cloudflare Workers `fetch` 默认走 HTTP/2 透明协商。
 */

const HOST_PRODUCTION = 'api.push.apple.com';
const HOST_SANDBOX = 'api.sandbox.push.apple.com';
const EXPIRATION_TTL_SEC = 24 * 60 * 60;

export interface ApnsPushRequest {
  jwt: string;
  topic: string;
  env: 'sandbox' | 'production';
  deviceToken: string;
  payload: Record<string, unknown>;
  pushType: 'alert' | 'background';
  collapseId?: string;
}

export interface ApnsResult {
  status: number;
  reason?: string;
}

export async function pushToApns(req: ApnsPushRequest): Promise<ApnsResult> {
  const host = req.env === 'production' ? HOST_PRODUCTION : HOST_SANDBOX;
  const url = `https://${host}/3/device/${req.deviceToken}`;

  const headers: Record<string, string> = {
    authorization: `bearer ${req.jwt}`,
    'apns-topic': req.topic,
    'apns-push-type': req.pushType,
    'apns-expiration': String(Math.floor(Date.now() / 1000) + EXPIRATION_TTL_SEC),
    'content-type': 'application/json',
  };
  if (req.collapseId) headers['apns-collapse-id'] = req.collapseId;

  const response = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(req.payload),
  });

  if (response.status === 200) return { status: 200 };

  let reason: string | undefined;
  try {
    const text = await response.text();
    if (text) {
      const parsed = JSON.parse(text) as { reason?: string };
      reason = parsed.reason;
    }
  } catch {
    /* ignore non-JSON body */
  }
  return { status: response.status, reason };
}

/// 是否需要从 KV 中清理失效 token。
export function isInvalidToken(result: ApnsResult): boolean {
  return result.status === 410 || (result.status === 400 && result.reason === 'BadDeviceToken');
}
