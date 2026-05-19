/**
 * KV 封装：device_key -> device_token 映射。
 * 与 bark-server `database.Database` 接口对应。
 */

const DEVICE_KEY_BYTES = 16;
const DEVICE_TOKEN_MAX_LEN = 160;

export class DeviceStorage {
  constructor(private readonly kv: KVNamespace) {}

  /// 读取 key 对应的 device_token。不存在返回 null。
  async getDeviceToken(deviceKey: string): Promise<string | null> {
    if (!deviceKey) return null;
    return this.kv.get(deviceKey);
  }

  /// 写入或更新 key 的 token。空 key 自动生成新 shortuuid。
  /// 返回最终使用的 key（新生成或传入）。
  async saveDeviceToken(deviceKey: string, deviceToken: string): Promise<string> {
    const finalKey = deviceKey || generateDeviceKey();
    await this.kv.put(finalKey, deviceToken);
    return finalKey;
  }

  /// 删除 key。
  async deleteDevice(deviceKey: string): Promise<void> {
    if (!deviceKey) return;
    await this.kv.delete(deviceKey);
  }
}

/// 校验 device_token 格式合法（非空 + 不超长）。
export function isValidDeviceToken(token: string): boolean {
  return token.length > 0 && token.length <= DEVICE_TOKEN_MAX_LEN;
}

/// 生成 22 字符 base64url device_key（128 bit 熵，等同 lithammer/shortuuid）。
export function generateDeviceKey(): string {
  const bytes = new Uint8Array(DEVICE_KEY_BYTES);
  crypto.getRandomValues(bytes);
  return base64UrlEncode(bytes);
}

function base64UrlEncode(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) {
    bin += String.fromCharCode(bytes[i] ?? 0);
  }
  return btoa(bin).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}
