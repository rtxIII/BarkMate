# BarkAgent — App Store 上架元数据草稿

> 用于填写 App Store Connect。⚠️ 标记项需你确认后替换。
> 语言：先出英文主区，中文简体可后补。

## 基本信息

| 字段 | 取值 |
|---|---|
| App Name | BarkAgent |
| Subtitle（30 字符内） | Push inbox for your AI agents |
| Bundle ID | com.barkagent.ios |
| Primary Category | Developer Tools |
| Secondary Category | Utilities |
| `LSApplicationCategoryType` | `public.app-category.developer-tools` ⚠️ 需加进 project.yml |
| Price | Free |
| Minimum iOS | 18.0 |
| Device | iPhone（iPad 兼容不优化） |

## Promotional Text（170 字符内，可随时改，不需审核）

Turn every script, CI run, and AI coding agent into a live status feed on
your iPhone. Aggregated task cards, step history, full-text search — all
on-device.

## Description

BarkAgent is a personal push inbox for developers who run scripts, CI
pipelines, and AI coding agents.

Point any Bark-compatible push at BarkAgent and it turns a stream of raw
notifications into clean, per-agent task cards with a real status machine:
running, waiting for input, blocked, done, failed, or stale.

WHAT YOU GET
• Agent Dashboard — every active agent as a live card, triaged by what needs
  you first
• Status machine — pushes sharing an agent + task id aggregate into one card
  with full step history
• Bark protocol compatible — reuse the push ecosystem you already have; zero
  new SDK to integrate
• Multiple servers — register several Bark servers and manage them per device
• End-to-end encryption — configure a key and payloads are AES-encrypted
  client-side
• Full-text search — across agent steps and incoming items
• Pin, mute, archive — keep the noisy ones quiet and the important ones on top

PRIVACY FIRST
• No account, no login
• No tracking, no analytics, no third-party analytics SDKs
• All data stays on device (SwiftData in an App Group container)
• Your APNs token is sent only to the Bark servers you configure

BarkAgent is read-only by design: it shows you what your agents are doing,
it never sends commands back.

## Keywords（100 字符内，逗号分隔，无空格更省字符）

bark,agent,push,notifications,ci,devops,webhook,inbox,status,developer,ai,automation,script,monitor

## URLs

| 字段 | 取值 |
|---|---|
| Support URL | `https://github.com/rtxIII/BarkMate` |
| Marketing URL | 待定（可选，暂留空） |
| Privacy Policy URL | `https://barkagent.we2.xyz/privacy` （已部署，见 BarkMateServer privacy.ts；中英双语 HTML） |

## App Privacy 答卷

- Data Collection: **Data Not Collected**（无任何数据收集）
- Tracking: No
- 对应 `PrivacyInfo.xcprivacy`：NSPrivacyTracking=false、无 CollectedDataTypes、
  仅 4 项 Required Reason API（UserDefaults CA92.1 / FileTimestamp C617.1 /
  DiskSpace E174.1 / SystemBootTime 35F9.1）

## App Review Information

| 字段 | 取值 |
|---|---|
| Sign-In required | No |
| Demo Account | 留空（无登录） |
| Notes | 粘贴 `BarkMate/REVIEW_NOTES.md` 全文 |
| Contact | r@rtx3.com ⚠️ 姓名/电话待填 |

## Export Compliance

`ITSAppUsesNonExemptEncryption = false`（已在 project.yml Info.plist 设好，
提交时无需重复上传合规文档）。

## 截图（必需）

⚠️ 尚未准备。App Store 要求至少 6.9"（iPhone 17 Pro Max 级）一组，
6.5" 可选（可由 6.9 缩放）。建议截图页面：

1. Agent Dashboard（heads-up 面板 + Running 段进度条）
2. Needs-you triage（waiting/blocked 卡）
3. Agent Detail（step 历史）
4. Search（状态 chip + 结果）
5. Setup（install 脚本 / curl）
6. Settings（多 server + 隐私段）

> 提示：`BarkMateUITests/__Screenshots__/iPhone17/` 下已有回归基线截图，
> 但那是测试帧（含 seed 数据、英文标准字号），可作构图参考，不能直接当商店图
> （需去除测试痕迹、加营销文案框）。

## 版本信息

| 字段 | 当前 | 上架前需改为 |
|---|---|---|
| MARKETING_VERSION | 0.1.0 | 1.0.0 |
| CURRENT_PROJECT_VERSION | 4 | 递增（如 5） |
| What's New | — | 首版可写 "Initial release." |
