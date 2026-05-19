/**
 * 共享类型定义。
 */

/// Cloudflare Worker 环境绑定。与 wrangler.jsonc 保持一致。
export type Bindings = {
  DEVICES: KVNamespace;
  APNS_TEAM_ID: string;
  APNS_KEY_ID: string;
  APNS_TOPIC: string;
  APNS_ENV: 'sandbox' | 'production';
  APNS_PRIVATE_KEY?: string;
};

/// 与 bark-server 的 CommonResp 兼容的统一响应结构。
export type CommonResponse<T = unknown> = {
  code: number;
  message: string;
  timestamp: number;
  data?: T;
};

export const ok = <T>(data?: T, message = 'success'): CommonResponse<T> => ({
  code: 200,
  message,
  timestamp: Math.floor(Date.now() / 1000),
  data,
});

export const failed = (code: number, message: string): CommonResponse => ({
  code,
  message,
  timestamp: Math.floor(Date.now() / 1000),
});
