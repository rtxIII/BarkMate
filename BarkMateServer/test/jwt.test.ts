import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
import { getApnsJwt, clearJwtCache } from '../src/apns/jwt';

let testPemA = '';
let testPemB = '';
let publicKeyA: CryptoKey;

async function generateTestKey(): Promise<{ pem: string; publicKey: CryptoKey }> {
  const pair = (await crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  )) as CryptoKeyPair;
  const pkcs8 = (await crypto.subtle.exportKey('pkcs8', pair.privateKey)) as ArrayBuffer;
  const bytes = new Uint8Array(pkcs8);
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]!);
  const b64 = btoa(bin);
  const lines = b64.match(/.{1,64}/g)?.join('\n') ?? b64;
  const pem = `-----BEGIN PRIVATE KEY-----\n${lines}\n-----END PRIVATE KEY-----\n`;
  return { pem, publicKey: pair.publicKey };
}

beforeAll(async () => {
  const keyA = await generateTestKey();
  testPemA = keyA.pem;
  publicKeyA = keyA.publicKey;
  testPemB = (await generateTestKey()).pem;
});

beforeEach(() => {
  clearJwtCache();
});

function decodeJwtParts(jwt: string): { header: unknown; payload: unknown; sigBytes: Uint8Array } {
  const parts = jwt.split('.');
  expect(parts.length).toBe(3);
  const decodeJsonPart = (s: string): unknown =>
    JSON.parse(atob(s.replaceAll('-', '+').replaceAll('_', '/')));
  const [headerPart, payloadPart, sigPart] = parts as [string, string, string];
  const padded = sigPart.replaceAll('-', '+').replaceAll('_', '/');
  const padding = padded.length % 4 === 0 ? '' : '='.repeat(4 - (padded.length % 4));
  const bin = atob(padded + padding);
  const sigBytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) sigBytes[i] = bin.charCodeAt(i);
  return {
    header: decodeJsonPart(headerPart),
    payload: decodeJsonPart(payloadPart),
    sigBytes,
  };
}

describe('getApnsJwt', () => {
  it('signs a valid ES256 JWT with expected header and claims', async () => {
    const jwt = await getApnsJwt({
      privateKeyPem: testPemA,
      teamId: 'TEAMXYZ123',
      keyId: 'KEYABC9876',
      nowSeconds: 1_700_000_000,
    });

    const { header, payload, sigBytes } = decodeJwtParts(jwt);
    expect(header).toEqual({ alg: 'ES256', kid: 'KEYABC9876', typ: 'JWT' });
    expect(payload).toEqual({ iss: 'TEAMXYZ123', iat: 1_700_000_000 });
    expect(sigBytes.length).toBe(64); // P-256 raw R||S

    // Verify signature with public key
    const signingInput = jwt.split('.').slice(0, 2).join('.');
    const verified = await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      publicKeyA,
      sigBytes,
      new TextEncoder().encode(signingInput),
    );
    expect(verified).toBe(true);
  });

  it('caches JWT for same teamId/keyId within 55min window', async () => {
    const jwt1 = await getApnsJwt({
      privateKeyPem: testPemA,
      teamId: 'T1',
      keyId: 'K1',
      nowSeconds: 1_000_000,
    });
    const jwt2 = await getApnsJwt({
      privateKeyPem: testPemA,
      teamId: 'T1',
      keyId: 'K1',
      nowSeconds: 1_000_000 + 60 * 30, // 30 min later
    });
    expect(jwt1).toBe(jwt2);
  });

  it('refreshes JWT after 55min expiration', async () => {
    const jwt1 = await getApnsJwt({
      privateKeyPem: testPemA,
      teamId: 'T2',
      keyId: 'K2',
      nowSeconds: 1_000_000,
    });
    const jwt2 = await getApnsJwt({
      privateKeyPem: testPemA,
      teamId: 'T2',
      keyId: 'K2',
      nowSeconds: 1_000_000 + 55 * 60 + 1, // just past expiry
    });
    expect(jwt1).not.toBe(jwt2);
  });

  it('uses separate cache entries per teamId', async () => {
    const a = await getApnsJwt({
      privateKeyPem: testPemA,
      teamId: 'T3',
      keyId: 'SAME_KID',
      nowSeconds: 2_000_000,
    });
    const b = await getApnsJwt({
      privateKeyPem: testPemB,
      teamId: 'T4',
      keyId: 'SAME_KID',
      nowSeconds: 2_000_000,
    });
    expect(a).not.toBe(b);
  });
});
