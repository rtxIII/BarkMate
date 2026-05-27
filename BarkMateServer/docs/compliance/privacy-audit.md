---
title: BarkMate Privacy Boundary Audit
version: 1.0
generated: 2026-05-27
scope: V1.0 candidate (iOS Phase 1-4 + Server S4a)
---

# 隐私边界审计 / Privacy Boundary Audit

本文档以可复现的 grep / dependency 证据,证明 BarkMate V1.0 候选版本除
"用户配置的 Bark 服务器" + "Apple APNs" 外不发起任何第三方网络出口,
且不集成任何分析 / 崩溃上报 / 广告 SDK。

> 复现命令均在仓库根目录 `/Users/mac/Zero/Proj/Coding/rtxiii/BarkMemo`
> 下执行;date 锚定 2026-05-27 / commit `02376d0`。

## 1. 网络出口清单

### 1.1 iOS 客户端

| 编号 | 出口 | 触发条件 | 协议 | 文件 |
|---|---|---|---|---|
| C-1 | 用户配置的 Bark 服务器 `/register` | 用户添加服务器 / 设备 token 变化 | HTTPS POST | `BarkService/BarkClient.swift:18-44` |
| C-2 | 用户配置的 Bark 服务器 `/ping` | ServerListView 下拉刷新 / 健康检查 | HTTPS GET | `BarkService/BarkClient.swift:50-62` |
| C-3 | 推送 payload 内嵌的 `image` URL | NSE 收到带 image 字段的推送 | HTTPS GET (10s timeout, ≤10MB) | `BarkService/ImageEnricher.swift:61-84` |

复现:
```sh
grep -rEn "URLSession|URLRequest|URLProtocol" \
  BarkMate/App BarkMate/Packages/BarkService \
  --include='*.swift' | grep -v Tests
```

iOS 内除 C-1 / C-2 / C-3 之外**没有**任何 `URLSession.data(...)` /
`URLRequest` / `URLProtocol` 调用。其余 `fetch(...)` 命中均是 SwiftData
的 `ModelContext.fetch`(本地数据库),非网络。

### 1.2 BarkMate 服务器

| 编号 | 出口 | 触发条件 | 协议 | 文件 |
|---|---|---|---|---|
| S-1 | `api.push.apple.com` 或 `api.sandbox.push.apple.com` | `POST /push` 收到合法请求 | HTTPS/2 with ES256 JWT | `BarkMateServer/src/apns/client.ts:37` |

复现:
```sh
grep -rEn "fetch\(|new URL|Request\(" BarkMateServer/src
```

`new URL(c.req.url)` 只解析进入服务器的请求 URL(不发出网络),
`fetch(url, ...)` 仅在 `apns/client.ts` 调用,目标域名由
`apns/jwt.ts` 与 `c.env.APNS_ENV` 决定,固定为 `*.push.apple.com`。

### 1.3 已确认**不存在**的出口

- ❌ 分析 / 遥测 (Google Analytics / Mixpanel / Amplitude / Segment)
- ❌ 崩溃上报 (Crashlytics / Sentry / Bugsnag / Datadog)
- ❌ 广告 / 归因 (AdMob / FB SDK / AppsFlyer / Adjust / Branch)
- ❌ 远程配置 (Firebase Remote Config / LaunchDarkly)
- ❌ 推送 SDK 中转 (FCM / OneSignal / Pushy)
- ❌ A/B 测试 / Feature flag 服务
- ❌ Cookie / 跨域跟踪 (App 不嵌 WebView)
- ❌ IDFA / SKAdNetwork / AppTrackingTransparency

复现:
```sh
grep -rEn "import (Sentry|Firebase|Analytics|Crashlytics|Mixpanel|Amplitude|Segment|Bugsnag|Datadog|GoogleAnalytics|FBSDKCore|OneSignal|Pushy|AppsFlyer|Adjust|Branch|LaunchDarkly|SKAdNetwork)" BarkMate
# 输出: (空)
```

## 2. 第三方依赖审计

### 2.1 iOS SPM 依赖

```sh
find BarkMate/Packages -name "Package.swift" -exec grep -h "url:" {} \;
```

唯二的外部 SPM 依赖:

| 包 | 版本 | 用途 | 是否发起网络 |
|---|---|---|---|
| `krzyzanowskim/CryptoSwift` | ≥1.8.0 | AES 解密 (CBC/ECB/GCM) | ❌ 纯计算 |
| `gonzalezreal/swift-markdown-ui` | ≥2.4.0 | Memo Markdown 渲染 | ❌ 纯渲染 |

两者均开源、可审计、无网络出口。

### 2.2 服务器 npm 依赖

```sh
cat BarkMateServer/package.json
```

唯一运行时依赖: `hono` (HTTP 路由框架,纯逻辑无第三方出口)。
Dev 依赖: `@cloudflare/*`, `vitest`, `wrangler`, `typescript` —
均不进 production bundle。

## 3. 数据最小化证据

### 3.1 服务器 KV 仅存 device token

```sh
grep -rEn "DEVICES\.put|DEVICES\.get|DEVICES\.delete" BarkMateServer/src
```

KV 仅写入 `device:<key> -> apns_token` 单一字段;无 IP、UA、地理位置、
请求体、推送内容留存。Workers 跨请求无状态,日志由 Cloudflare 平台
按其默认策略处理(可在 Worker 配置关闭 `observability.logs`)。

### 3.2 推送 payload 不落盘

```sh
grep -rEn "DEVICES\.put|DEVICES\.delete" BarkMateServer/src/routes/push.ts
```

`/push` 路由不写 KV(只读 `DEVICES.get` 拿目标 token),
`apns/client.ts` 把构造好的 payload 直接 fetch 到 APNs,
请求结束即销毁。

### 3.3 客户端本地数据范围

```sh
grep -rEn "@Model" BarkMate/Packages/Models/Sources
```

SwiftData 中只有以下用户数据,全部位于
`group.com.barkmate.shared` App Group 容器内:

- `Server` — 用户配置的 Bark 服务器
- `AgentTask` / `AgentStep` — 收到的 agent 状态推送聚合
- `Memo` — 旧 Bark 协议消息 + V1.2 用户备忘录
- `CryptoConfig` — AES 密钥配置(实际 key 在 Keychain)
- `PendingPayload` — 写库失败时的重试队列

无设备识别码、无地理位置、无通讯录、无生物特征。

### 3.4 Keychain 范围

```sh
grep -rEn "kSecAttrAccessGroup|Keychain" BarkMate --include='*.swift' | grep -v Tests
```

Keychain 仅存:
- 各 Bark 服务器的 `key`(由服务器分配的设备 ID)
- AES 端到端解密密钥(若用户启用)

`kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`,
不参与 iCloud Keychain 同步。

## 4. 加密链路

| 段 | 加密 | 实现 |
|---|---|---|
| iOS App ↔ Bark 服务器 | TLS 1.2+ | URLSession 默认 ATS |
| Bark 服务器 ↔ APNs | TLS 1.2+ HTTP/2 + ES256 JWT | `apns/jwt.ts` + Workers fetch |
| APNs ↔ iOS 设备 | Apple 端到端 (内置) | iOS 系统栈 |
| 推送 payload(可选 E2EE) | AES-128/192/256 CBC/ECB/GCM | NSE 内 CryptoSwift 解密 |

ATS (App Transport Security) 全开,不在 Info.plist 添加任何
`NSAppTransportSecurity` 例外。

复现:
```sh
grep -En "NSAppTransportSecurity|NSAllowsArbitraryLoads" BarkMate/App/Info.plist
# 输出: (空)
```

## 5. 用户控制权证据

| 操作 | 入口 | 效果 |
|---|---|---|
| 删除单条服务器注册 | App `Settings → Servers → swipe delete` | 触发 `DELETE /register/:key`,KV 立即移除 |
| 删除全部本地数据 | iOS Settings → 卸载 App | App Group 容器与 Keychain 项一并清除 |
| 自部署服务器 | `BarkMateServer/README.md` 全流程文档 | 用户可完全脱离我们运营的实例 |
| 关闭 E2EE | App 不写入 `CryptoConfig` | 服务器透传明文 payload(仍走 TLS) |
| 撤销通知权限 | iOS Settings → BarkMate → Notifications | iOS 自动作废 APNs token |

## 6. 审计签名

本审计基于 commit `02376d0` 与 plan.md 0.4.1 (V1.0 候选状态)。
任何引入新依赖、新出口或新存储字段的改动**必须**:

1. 更新 `docs/compliance/privacy-policy.md` §2 / §5
2. 更新本文件 §1 / §2 / §3
3. 在 PR 描述中标注 `privacy-impact: yes`

CI 建议(后续接入,不阻塞 V1.0):

```sh
# Fail if new SDK or domain literal lands without docs touch
grep -rE "(api\.|sdk\.|telemetry\.|analytics\.)" --include='*.swift' BarkMate \
  | grep -vE "barkmate\.we2\.xyz|push\.apple\.com|user-configured" \
  && exit 1 || true
```
