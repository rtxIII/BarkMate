/**
 * 扩展 `Cloudflare.Env`，让 `env.DEVICES` 等绑定有类型。
 * 适用于源码（Hono `c.env`）和测试（`cloudflare:test` 的 `env`）。
 */

import type { Bindings } from '../src/types';

declare global {
  namespace Cloudflare {
    interface Env extends Bindings {}
  }
}

export {};
