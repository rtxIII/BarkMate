/**
 * APNs JWT 签发（ES256 / Web Crypto API）。
 * Apple 接受同一 token 最多 60 分钟，本模块缓存 55 分钟（5 分钟余量）。
 */

const JWT_TTL_SEC = 55 * 60;

interface CacheEntry {
  token: string;
  expiresAt: number;
}

const cache = new Map<string, CacheEntry>();

export interface JwtOpts {
  privateKeyPem: string;
  teamId: string;
  keyId: string;
  /// 测试钩子：覆盖当前时间（unix seconds）。生产不传。
  nowSeconds?: number;
}

/// 获取 APNs JWT。同 (teamId, keyId) 组合在 55 分钟内复用。
export async function getApnsJwt(opts: JwtOpts): Promise<string> {
  const cacheKey = `${opts.teamId}:${opts.keyId}`;
  const now = opts.nowSeconds ?? Math.floor(Date.now() / 1000);

  const hit = cache.get(cacheKey);
  if (hit && hit.expiresAt > now) return hit.token;

  const token = await signJwt(opts, now);
  cache.set(cacheKey, { token, expiresAt: now + JWT_TTL_SEC });
  return token;
}

export function clearJwtCache(): void {
  cache.clear();
}

async function signJwt(opts: JwtOpts, nowSeconds: number): Promise<string> {
  const key = await importPkcs8Key(opts.privateKeyPem);

  const header = base64UrlEncodeJson({ alg: 'ES256', kid: opts.keyId, typ: 'JWT' });
  const payload = base64UrlEncodeJson({ iss: opts.teamId, iat: nowSeconds });
  const signingInput = `${header}.${payload}`;

  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64UrlEncodeBytes(new Uint8Array(signature))}`;
}

async function importPkcs8Key(pem: string): Promise<CryptoKey> {
  // Tolerate various PEM dialects: any -----...----- header / footer,
  // strip every non-base64 char from the body.
  const body = pem
    .replace(/-----[A-Z ]+-----/g, '')
    .replace(/[^A-Za-z0-9+/=]/g, '');
  if (!body) throw new Error('JWT: empty PEM body after strip');
  if (body.length < 100) {
    throw new Error(`JWT: PEM body suspiciously short (${body.length} chars). Re-inject the .p8 secret.`);
  }

  const bytes = base64DecodeToBytes(body);
  try {
    return await crypto.subtle.importKey(
      'pkcs8',
      bytes,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['sign'],
    );
  } catch (err) {
    const detail =
      err instanceof Error ? err.message : String(err);
    throw new Error(
      `JWT: importKey failed (${detail}). PEM body length=${body.length} bytes=${bytes.length}.`,
    );
  }
}

function base64UrlEncodeJson(obj: unknown): string {
  return base64UrlEncodeBytes(new TextEncoder().encode(JSON.stringify(obj)));
}

function base64UrlEncodeBytes(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) {
    bin += String.fromCharCode(bytes[i] ?? 0);
  }
  return btoa(bin).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

function base64DecodeToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
