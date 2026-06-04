---
title: BarkAgent Privacy Policy / 隐私政策
version: 1.0
effective_date: 2026-05-27
canonical_url: https://barkmate.we2.xyz/privacy
---

# BarkAgent Privacy Policy

> Effective: 2026-05-27 · Version 1.0
> Canonical URL: https://barkmate.we2.xyz/privacy
> Plain-text mirror: https://barkmate.we2.xyz/privacy.txt

This policy describes how the BarkAgent iOS application ("the App") and the
BarkAgent self-hosted push relay ("the Server", deployed at
`barkmate.we2.xyz`) handle your data. The App and the Server are open source.

---

## 1. Who we are

BarkAgent is an open-source project. The App is distributed through the
Apple App Store. The Server is a Cloudflare Worker that the maintainers
operate at `barkmate.we2.xyz` and that any user may also self-host.

We do not operate analytics, advertising, attribution, or crash-reporting
infrastructure. The App contains no third-party SDKs.

Contact: open an issue at the project repository.

## 2. What data we process

### 2.1 On your device

The App stores the following data **locally** on your iPhone, inside the
App Group container `group.com.barkmate.shared` and the Keychain access
group of the same identifier:

| Data | Purpose | Where |
|---|---|---|
| APNs device token | Receive push notifications | App Group SwiftData store |
| Configured server addresses + API keys | Send pushes through your relay | SwiftData + Keychain |
| Optional AES key | Decrypt encrypted payloads on device | Keychain only |
| AgentTask / AgentStep / Memo records | Display history and dashboard | App Group SwiftData store |
| User-selected memo image attachments | Attach images to memos | App Group resources directory |
| Cached push images | Show rich notifications | Notification Service Extension cache |

This data never leaves your device except when you explicitly send a
network request to a server you configured (see §2.2) or when iOS
delivers a push (see §2.3).

### 2.2 On the BarkAgent Server

When the App registers a device with the Server, the Server stores in
Cloudflare KV:

| Key | Value | Retention |
|---|---|---|
| `device:<device_key>` | APNs device token | Until you call `DELETE /register/:key` or rotate the token |

The Server does **not** log push bodies, does **not** persist push
payloads, and does **not** retain request bodies after the request
finishes. Workers are stateless across requests.

### 2.3 In transit

The App makes outbound HTTPS requests to:

1. **Your configured Bark server(s)** — for device registration
   (`POST /register/:device_key`) and health checks (`GET /ping`).
   You decide which servers to add.
2. **Image URLs embedded inside a push payload** — when the sender
   includes an `image=` field, the Notification Service Extension
   downloads it to render a rich notification. The image host is chosen
   by whoever sent the push, not by BarkAgent.

The Server makes outbound HTTPS requests to:

3. **Apple Push Notification service** at `api.push.apple.com` or
   `api.sandbox.push.apple.com`, signed with an ES256 JWT, to deliver
   the push you sent.

No other network destinations are contacted.

## 3. What we do not collect

We do not collect, transmit, or store: your name, email, phone number,
contacts, calendar, location, advertising identifier (IDFA), device
fingerprint, browsing history, microphone, camera, health, or biometric
data. The App never asks for these permissions. If you attach an image
to a memo, iOS presents a system photo picker and BarkAgent stores only
the image you selected, locally on your device.

## 4. Encryption

Pushes may be encrypted client-to-client with AES-128/192/256 in CBC,
ECB, or GCM mode. When encryption is enabled:

- The key lives only in your iPhone's Keychain.
- The Server transports ciphertext only and cannot read the plaintext.
- Decryption happens inside the Notification Service Extension on your
  device.

Transport security: all network traffic uses HTTPS (TLS 1.2+). APNs JWT
is signed locally on the Server with ES256 using a private key stored as
a Wrangler secret.

## 5. Data sharing

We do **not** sell, rent, or share your data. The only entities that
ever see any BarkAgent-related traffic are:

- **Apple** — to deliver the push (Apple's privacy policy applies to
  the APNs payload).
- **Cloudflare** — as our Worker host (Cloudflare's privacy policy
  applies to request metadata).
- **The operator of any Bark server you added** — which may be
  yourself, if you self-host.

## 6. Your choices and rights

- **Delete a device registration**: send `DELETE /register/:device_key`
  to the Server, or uninstall the App (iOS revokes the APNs token).
- **Delete local data**: uninstall the App, or use the in-app data
  management controls.
- **Self-host**: deploy your own Server using the open-source code; the
  App can talk to multiple servers and you can remove the default one.
- **Inspect**: the source code is public; you can audit every byte sent
  on the wire.

## 7. Children

BarkAgent is not directed to children under 13 and we do not knowingly
collect data from them.

## 8. Changes

Material changes to this policy will bump the version number above and
will be announced on the project repository before they take effect.

---

# BarkAgent 隐私政策

> 生效日期: 2026-05-27 · 版本 1.0
> 正式地址: https://barkmate.we2.xyz/privacy
> 纯文本镜像: https://barkmate.we2.xyz/privacy.txt

本政策说明 BarkAgent iOS 应用("应用")与 BarkAgent 自部署推送中继
("服务器",运行于 `barkmate.we2.xyz`)如何处理您的数据。两者均为开源。

---

## 1. 我们是谁

BarkAgent 是开源项目。应用通过 App Store 分发,服务器由维护者运行在
`barkmate.we2.xyz`,任何用户也可以自行部署。

我们不运营任何分析、广告、归因或崩溃上报基础设施。应用不包含任何第三方
SDK。

联系方式:请到项目仓库提 issue。

## 2. 我们处理哪些数据

### 2.1 在您的设备上

应用在您的 iPhone 本地存储以下数据,位于 App Group 容器
`group.com.barkmate.shared` 以及同名 Keychain Access Group 中:

| 数据 | 用途 | 位置 |
|---|---|---|
| APNs device token | 接收推送 | App Group SwiftData 库 |
| 已配置的服务器地址 + API key | 通过您的中继发推送 | SwiftData + Keychain |
| 可选的 AES 密钥 | 端侧解密加密推送 | 仅 Keychain |
| AgentTask / AgentStep / Memo 记录 | 展示历史与 Dashboard | App Group SwiftData 库 |
| 用户主动选择的 Memo 图片附件 | 给备忘录附加图片 | App Group resources 目录 |
| 缓存的推送图片 | 显示富文本通知 | NSE 缓存 |

除非您主动向所配置的服务器发起请求(见 §2.2)或 iOS 投递推送(见 §2.3),
这些数据不会离开您的设备。

### 2.2 在 BarkAgent 服务器上

应用向服务器注册设备时,服务器在 Cloudflare KV 中存储:

| 键 | 值 | 留存 |
|---|---|---|
| `device:<device_key>` | APNs device token | 直至您调用 `DELETE /register/:key` 或 token 失效 |

服务器**不**记录推送内容、**不**持久化推送 payload、请求结束后**不**留存
请求体。Workers 跨请求无状态。

### 2.3 在传输过程中

应用对外发起 HTTPS 请求到:

1. **您配置的 Bark 服务器** — 用于设备注册
   (`POST /register/:device_key`)与健康检查(`GET /ping`)。由您决定加哪些。
2. **推送 payload 内嵌的图片 URL** — 发推送时若带 `image=` 字段,
   NSE 会下载图片以渲染富通知。图片的宿主由发送方决定,而不是 BarkAgent。

服务器对外发起 HTTPS 请求到:

3. **Apple APNs**(`api.push.apple.com` 或 `api.sandbox.push.apple.com`),
   使用 ES256 JWT 签名,投递您发的推送。

除此之外不接触其他网络目标。

## 3. 我们不收集的内容

我们不收集、传输或存储: 姓名、邮箱、电话、通讯录、日历、位置、广告标识
(IDFA)、设备指纹、浏览历史、麦克风、相机、健康或生物特征数据。应用从不
申请这些权限。如果您给备忘录附加图片,iOS 会显示系统照片选择器,BarkAgent
只在本机保存您主动选择的图片。

## 4. 加密

推送可使用 AES-128/192/256(CBC / ECB / GCM)做端到端加密。开启加密时:

- 密钥只存在于您 iPhone 的 Keychain。
- 服务器只转发密文,无法读取明文。
- 解密在设备的 NSE 内完成。

传输安全: 所有网络流量使用 HTTPS(TLS 1.2+)。APNs JWT 在服务器本地用
ES256 签名,私钥作为 Wrangler secret 存储。

## 5. 数据共享

我们**不**售卖、出租或共享您的数据。唯一会接触到 BarkAgent 相关流量的
第三方:

- **Apple** — 用于投递推送(其隐私政策适用于 APNs payload)。
- **Cloudflare** — 作为 Worker 宿主(其隐私政策适用于请求元数据)。
- **您添加的 Bark 服务器运营者** — 如果您自部署,这就是您自己。

## 6. 您的选择与权利

- **删除设备注册**: 向服务器发 `DELETE /register/:device_key`,或卸载应用
  (iOS 会作废 APNs token)。
- **删除本地数据**: 卸载应用,或使用应用内数据管理入口。
- **自部署**: 用开源代码部署您自己的服务器;应用支持多服务器,可以删掉
  默认服务器。
- **审查**: 源代码公开,您可以审计每一字节的网络出口。

## 7. 儿童

BarkAgent 不面向 13 岁以下儿童设计,我们也不会有意收集他们的数据。

## 8. 变更

本政策的重大变更会更新顶部版本号,并在生效前于项目仓库公告。
