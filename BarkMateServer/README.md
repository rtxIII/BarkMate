# BarkAgentServer

BarkAgent 推送通知服务器 — TypeScript + Cloudflare Workers + KV。
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
| GET | `/info` | ✅ S4a | server capabilities + `auth_required` flag |
| POST | `/register` | ✅ S2 | 注册设备 |
| GET | `/register` | ✅ S2 | Legacy compat |
| GET | `/register/:device_key` | ✅ S2 | 检查 key 有效性 |
| POST | `/push` | ✅ S3 | V2 JSON 推送(含 v0.3 字段透传) |
| POST | `/liveactivity/:token` | ✅ S4b | ActivityKit 远程 update/end 推送 |
| POST | `/:device_key/...` | ✅ S3 | V1 路径参数兼容 |

详见 [doc/plan.md](../doc/plan.md) 服务器端实施计划部分。

### Live Activity push

`/liveactivity/:token` 的 `token` 是 iOS `Activity.pushTokenUpdates` 产出的
per-activity APNs token,不是 `/register` 存入 KV 的 Bark `device_key`。

```bash
curl -X POST "https://barkmate.we2.xyz/liveactivity/$ACTIVITY_TOKEN" \
  -H "content-type: application/json" \
  -d '{
    "event": "update",
    "content_state": {
      "status": "running",
      "progress": "3/8",
      "eta": "2026-06-04T12:00:00Z"
    },
    "priority": 10,
    "collapse_id": "demo-agent::task-1"
  }'
```

支持 `event=update|end`。server 会使用 APNs topic
`<APNS_TOPIC>.push-type.liveactivity` 和 `apns-push-type: liveactivity`。

## CI / 部署

- **CI**: `.github/workflows/ci.yml` push/PR 自动跑 `npm run typecheck` + `npm test`
- **Deploy**: `.github/workflows/deploy.yml` push 到 `main` 且包含 `BarkMateServer/**` 改动时自动 `wrangler deploy`;也支持手动 workflow_dispatch

### 需要在 GitHub Repo Secrets 配置

| Secret | 来源 | 说明 |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | Cloudflare → My Profile → API Tokens → 创建 "Edit Cloudflare Workers" template | Wrangler 部署用 |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare → Workers & Pages → 右侧栏 Account ID | Wrangler 部署目标账号 |

注:`APNS_PRIVATE_KEY` 不通过 GitHub Secrets,而是直接 `wrangler secret put APNS_PRIVATE_KEY` 注入到 Worker(只需做一次,后续 deploy 不影响)。

### 可选:`BARKMATE_AUTH_TOKEN`

设置后所有非 `/healthz|/ping|/info` 路径需要 `Authorization: Bearer <token>`,客户端在 BarkClient 调用前注入。未设置时与原 bark 协议完全兼容。

```bash
pnpm wrangler secret put BARKMATE_AUTH_TOKEN
```
