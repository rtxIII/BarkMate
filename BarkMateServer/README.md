# BarkMateServer

BarkMate 推送通知服务器 — TypeScript + Cloudflare Workers + KV。
协议兼容原 [bark-server](https://github.com/Finb/bark-server)（`/register` / `/push` / `/ping`）。

## Stack

- **Runtime**: Cloudflare Workers
- **Framework**: [Hono](https://hono.dev) v4
- **Storage**: Cloudflare KV (`DEVICES` namespace, `device_key -> device_token`)
- **APNs**: Web Crypto API (ES256 JWT) → `api.push.apple.com` (HTTP/2)
- **Test**: Vitest + `@cloudflare/vitest-pool-workers`

## 本地开发

```bash
# 1. 安装依赖
pnpm install

# 2. 类型检查
pnpm typecheck

# 3. 单元测试
pnpm test

# 4. 启动本地开发服务（默认 :8787）
pnpm dev

# 5. 验证
curl http://localhost:8787/healthz
# => {"code":200,"message":"success","timestamp":...,"data":{"status":"ok"}}
```

## 首次部署

```bash
# 1. 登录 Cloudflare 账号
pnpm wrangler login

# 2. 创建 KV namespace（生产 + preview 各一个）
pnpm wrangler kv namespace create DEVICES
pnpm wrangler kv namespace create DEVICES --preview

# 把返回的 id / preview_id 填入 wrangler.jsonc 的 kv_namespaces[0]

# 3. 配置 APNs 凭证（vars 公开 + secret 私密）
# 编辑 wrangler.jsonc 的 vars: APNS_TEAM_ID / APNS_KEY_ID
# 注入 p8 私钥（secret）：
pnpm wrangler secret put APNS_PRIVATE_KEY
# (粘贴 .p8 文件全部内容，含 BEGIN/END 行)

# 4. 部署
pnpm deploy
```

## 环境配置

| 名称 | 类型 | 说明 |
|---|---|---|
| `APNS_TEAM_ID` | var | Apple Developer Team ID（10 字符）|
| `APNS_KEY_ID` | var | APNs Key ID（10 字符，p8 文件名中那段）|
| `APNS_TOPIC` | var | APNs topic = iOS app bundle id（默认 `com.barkmate.ios`）|
| `APNS_ENV` | var | `sandbox`（开发）/ `production`（TestFlight + AppStore）|
| `APNS_PRIVATE_KEY` | **secret** | p8 文件原文，多行字符串 |

## API 端点（实施中）

| Method | Path | 状态 | 说明 |
|---|---|---|---|
| GET | `/healthz` | ✅ S1 | 健康检查 |
| GET | `/ping` | ✅ S1 | 服务可用性，返回 `pong` |
| POST | `/register` | ⏳ S2 | 注册设备 |
| GET | `/register` | ⏳ S2 | Legacy compat |
| GET | `/register/:device_key` | ⏳ S2 | 检查 key 有效性 |
| POST | `/push` | ⏳ S3 | V2 JSON 推送 |
| POST | `/:device_key/...` | ⏳ S3 | V1 路径参数兼容 |

详见 [doc/plan.md](../doc/plan.md) 服务器端实施计划部分。
