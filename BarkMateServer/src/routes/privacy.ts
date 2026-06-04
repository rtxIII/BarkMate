/**
 * 隐私政策端点。
 * - GET /privacy      → text/html (中英双语,App Store Connect 填这个 URL)
 * - GET /privacy.txt  → text/plain (纯文本镜像,便于审计 / curl 查阅)
 *
 * 内容是合规文档的精简发布版本;权威源在
 * docs/compliance/privacy-policy.md(中英完整段落)。
 */

import { Hono } from 'hono';
import type { Bindings } from '../types';

const VERSION = '1.0';
const EFFECTIVE_DATE = '2026-05-27';

export const privacyRoute = new Hono<{ Bindings: Bindings }>();

privacyRoute.get('/privacy', (c) => {
  return c.html(renderHtml(), 200, {
    'cache-control': 'public, max-age=3600',
  });
});

privacyRoute.get('/privacy.txt', (c) => {
  return c.text(renderText(), 200, {
    'content-type': 'text/plain; charset=utf-8',
    'cache-control': 'public, max-age=3600',
  });
});

function renderHtml(): string {
  return `<!doctype html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>BarkAgent Privacy Policy / 隐私政策</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.6 -apple-system, "PingFang SC", "Helvetica Neue", Arial, sans-serif;
         max-width: 760px; margin: 2rem auto; padding: 0 1rem; color: #1a1a1a; }
  @media (prefers-color-scheme: dark) { body { background: #0e0e10; color: #ececec; } a { color: #7ab8ff; } }
  h1 { font-size: 1.6rem; margin-top: 2rem; }
  h2 { font-size: 1.15rem; margin-top: 1.6rem; }
  table { border-collapse: collapse; width: 100%; margin: 0.6rem 0; font-size: 0.95rem; }
  th, td { border: 1px solid currentColor; padding: 6px 10px; text-align: left; vertical-align: top; }
  th { font-weight: 600; }
  code { font: 0.9em "SF Mono", Menlo, monospace; }
  hr { border: none; border-top: 1px solid currentColor; opacity: 0.2; margin: 2rem 0; }
  .meta { opacity: 0.7; font-size: 0.9rem; }
</style>
</head>
<body>

<p class="meta">Version ${VERSION} · Effective ${EFFECTIVE_DATE} · <a href="/privacy.txt">plain text</a></p>

<h1>BarkAgent Privacy Policy</h1>

<p>This policy describes how the BarkAgent iOS application ("the App") and the BarkAgent
self-hosted push relay ("the Server", deployed at <code>barkmate.we2.xyz</code>) handle
your data. The App and the Server are open source.</p>

<h2>1. Who we are</h2>
<p>BarkAgent is an open-source project. We do not operate analytics, advertising,
attribution, or crash-reporting infrastructure. The App contains no third-party SDKs.</p>

<h2>2. Data we process</h2>
<p><strong>On your device</strong>: APNs device token, configured server addresses + API
keys, optional AES key (Keychain only), AgentTask / AgentStep / Memo records,
user-selected memo image attachments, cached push images. Stored inside the App Group
container <code>group.com.barkmate.shared</code>.</p>
<p><strong>On the Server</strong>: Cloudflare KV stores only
<code>device:&lt;key&gt; → APNs token</code>. We do not log push bodies and do not
persist push payloads.</p>
<p><strong>In transit</strong>: HTTPS to (a) the Bark servers you configured, (b) image
URLs embedded inside push payloads (chosen by the sender), and (c) Apple Push
Notification service. No other network destinations are contacted.</p>

<h2>3. What we do not collect</h2>
<p>Name, email, phone, contacts, calendar, location, IDFA, device fingerprint, browsing
history, microphone, camera, health, biometric data — none. The App never asks for these
permissions. If you attach an image to a memo, iOS presents a system photo picker and
BarkAgent stores only the image you selected, locally on your device.</p>

<h2>4. Encryption</h2>
<p>Pushes may be end-to-end encrypted with AES-128/192/256. Keys live only in your
iPhone's Keychain; the Server transports ciphertext only. APNs JWT is signed locally on
the Server with ES256.</p>

<h2>5. Sharing</h2>
<p>We do not sell, rent, or share your data. The only entities that ever see BarkAgent
traffic are <strong>Apple</strong> (push delivery), <strong>Cloudflare</strong> (Worker
host), and <strong>the operator of any Bark server you added</strong> — which may be
yourself.</p>

<h2>6. Your rights</h2>
<p>Delete a registration via <code>DELETE /register/:device_key</code>; delete local data
by uninstalling; self-host the open-source Server; audit every byte on the wire via the
public source code.</p>

<h2>7. Children</h2>
<p>BarkAgent is not directed to children under 13 and we do not knowingly collect data
from them.</p>

<h2>8. Contact</h2>
<p>Open an issue at the project repository.</p>

<hr />

<h1>BarkAgent 隐私政策</h1>

<p>本政策说明 BarkAgent iOS 应用("应用")与 BarkAgent 自部署推送中继("服务器",运行于
<code>barkmate.we2.xyz</code>)如何处理您的数据。两者均为开源。</p>

<h2>1. 我们是谁</h2>
<p>BarkAgent 是开源项目。我们不运营任何分析、广告、归因或崩溃上报基础设施。应用不包含
任何第三方 SDK。</p>

<h2>2. 我们处理哪些数据</h2>
<p><strong>在您的设备上</strong>:APNs device token、已配置的服务器地址 + API key、
可选 AES 密钥(仅 Keychain)、AgentTask / AgentStep / Memo 记录、用户主动选择的
Memo 图片附件、推送图片缓存。位于 App Group 容器 <code>group.com.barkmate.shared</code>
内。</p>
<p><strong>在服务器上</strong>:Cloudflare KV 只存
<code>device:&lt;key&gt; → APNs token</code>。我们不记录推送内容,也不持久化推送
payload。</p>
<p><strong>传输中</strong>:HTTPS 到(a)您配置的 Bark 服务器,(b)推送 payload 内嵌
的图片 URL(由发送方决定),(c)Apple APNs。除此之外不接触其他网络目标。</p>

<h2>3. 我们不收集的内容</h2>
<p>姓名、邮箱、电话、通讯录、日历、位置、IDFA、设备指纹、浏览历史、麦克风、
相机、健康或生物特征数据 — 都不收集。应用从不申请这些权限。如果您给备忘录附加
图片,iOS 会显示系统照片选择器,BarkAgent 只在本机保存您主动选择的图片。</p>

<h2>4. 加密</h2>
<p>推送可使用 AES-128/192/256 端到端加密,密钥只存在于您 iPhone 的 Keychain。服务器
仅转发密文。APNs JWT 在服务器本地用 ES256 签名。</p>

<h2>5. 共享</h2>
<p>我们不售卖、出租或共享您的数据。唯一会接触到 BarkAgent 流量的第三方:
<strong>Apple</strong>(投递推送)、<strong>Cloudflare</strong>(Worker 宿主)、以及
<strong>您添加的 Bark 服务器运营者</strong>(自部署时即您本人)。</p>

<h2>6. 您的权利</h2>
<p>调用 <code>DELETE /register/:device_key</code> 删除注册;卸载应用清除本地数据;
使用开源代码自部署服务器;通过公开源代码审计每一字节的网络出口。</p>

<h2>7. 儿童</h2>
<p>BarkAgent 不面向 13 岁以下儿童,我们也不会有意收集其数据。</p>

<h2>8. 联系方式</h2>
<p>请到项目仓库提 issue。</p>

</body>
</html>
`;
}

function renderText(): string {
  return [
    `BarkAgent Privacy Policy`,
    `Version ${VERSION} · Effective ${EFFECTIVE_DATE}`,
    `Canonical: https://barkmate.we2.xyz/privacy`,
    ``,
    `1. Who we are`,
    `   Open-source project. No analytics, ads, attribution, crash-reporting, or third-party SDKs.`,
    ``,
    `2. Data we process`,
    `   - On device: APNs token, server addresses + keys, optional AES key (Keychain), AgentTask/AgentStep/Memo, user-selected memo image attachments, cached push images. App Group: group.com.barkmate.shared.`,
    `   - On server (Cloudflare KV): device:<key> -> APNs token only. No push bodies logged. No payload persistence.`,
    `   - In transit: HTTPS to (a) your configured Bark servers, (b) image URLs in push payloads, (c) Apple APNs. No other destinations.`,
    ``,
    `3. We do NOT collect`,
    `   name, email, phone, contacts, calendar, location, IDFA, device fingerprint, browsing history, microphone, camera, health, biometric data. User-selected memo image attachments are stored locally only.`,
    ``,
    `4. Encryption`,
    `   AES-128/192/256 end-to-end (CBC/ECB/GCM). Keys live in iPhone Keychain only. Server transports ciphertext only. APNs JWT signed locally with ES256.`,
    ``,
    `5. Sharing`,
    `   We do not sell, rent, or share data. Only third parties seeing traffic: Apple (push), Cloudflare (Worker host), operator of any Bark server you added.`,
    ``,
    `6. Your rights`,
    `   - Delete registration: DELETE /register/:device_key`,
    `   - Delete local data: uninstall the App`,
    `   - Self-host: open-source Server code`,
    `   - Audit: source code is public`,
    ``,
    `7. Children`,
    `   Not directed to children under 13.`,
    ``,
    `8. Contact`,
    `   Open an issue at the project repository.`,
    ``,
    `--- 中文 ---`,
    ``,
    `BarkAgent 隐私政策`,
    `版本 ${VERSION} · 生效 ${EFFECTIVE_DATE}`,
    ``,
    `1. 我们是谁:开源项目,无分析/广告/归因/崩溃上报/第三方 SDK。`,
    `2. 数据处理:`,
    `   - 设备本地:APNs token、服务器配置、可选 AES key (Keychain)、AgentTask/AgentStep/Memo、用户主动选择的 Memo 图片附件、推送图片缓存。位于 App Group group.com.barkmate.shared。`,
    `   - 服务器 KV:仅 device:<key> -> APNs token。不记录推送内容,不持久化 payload。`,
    `   - 传输:HTTPS 至(a) 您配置的 Bark 服务器、(b) 推送内嵌的图片 URL、(c) Apple APNs。`,
    `3. 不收集:姓名、邮箱、电话、通讯录、日历、位置、IDFA、指纹、浏览历史、麦克风、相机、健康或生物特征。用户主动选择的 Memo 图片附件仅保存在本机。`,
    `4. 加密:AES-128/192/256 端到端,密钥只在 iPhone Keychain。服务器仅转密文。APNs JWT 本地 ES256 签名。`,
    `5. 共享:不售卖、不出租、不共享。仅 Apple、Cloudflare、您添加的服务器运营者会接触到流量。`,
    `6. 权利:调用 DELETE /register/:device_key、卸载清本地、可自部署、源代码可审计。`,
    `7. 儿童:不面向 13 岁以下。`,
    `8. 联系:项目仓库 issue。`,
    ``,
  ].join('\n');
}
