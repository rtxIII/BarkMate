# BarkMate — 实施计划

> 版本: 0.3.1 | 日期: 2026-05-19 | 状态: **Client Phase 1 ✅ · Server MS1 ✅ · V1.0/V1.1/V1.2 范围已对齐 product.md**

## 架构概览

双端系统：

```
┌──────────────┐          ┌──────────────────────┐        ┌──────────┐
│  BarkMate    │ register │  BarkMateServer      │  push  │   APNs   │
│  iOS App     ├─────────►│  (Cloudflare Worker) ├───────►│  Apple   │
│              │◄─────────┤  + KV storage        │        │          │
│              │  /push   │                      │        └─────┬────┘
└──────────────┘          └──────────────────────┘              │
      ▲                                                         │
      │ APNs push (含 v0.3 agent_status / task_id 等可选字段)   │
      └─────────────────────────────────────────────────────────┘
```

- **iOS 客户端**：Swift + SwiftUI + SwiftData，见 [iOS 客户端实施计划](#ios-客户端实施计划)
- **服务器端**：TypeScript + Cloudflare Workers + KV，见 [服务器端实施计划](#服务器端实施计划-barkmateserver)

V1.0 目标：交付 P0 功能闭环——**Agent Dashboard + 状态机推送接收 + Agent 详情页 + 多服务器 + 搜索**。Live Activity / Widget / 设备端 LLM 总结进入 V1.1；备忘录 / Share Extension / Siri 进入 V1.2。

### 关键技术决策

**iOS 客户端**
- 部署目标 iOS 17.0；Apple Intelligence / FoundationModels 相关特性走 `@available(iOS 18.1, *)` 自适应
- swift-tools-version 6.0
- DI 框架 Factory 2.5.x（仅 App + Extension target）
- 新模块：`AgentKit` / `ActivityKit-Wrapper` / `LiveActivityExtension`（Phase 2-3 引入）

**服务器端**
- 语言：TypeScript（严格模式）；运行时 Cloudflare Workers + KV
- 推送：APNs HTTP/2 + ES256 JWT（Web Crypto API）
- 框架：Hono
- **V0.3 新增**：`/push` 接受 `agent_status` / `task_id` / `progress` / `eta` 等可选字段，透传至 APNs payload（V1.0 必需）；后续 V1.1 增 Live Activity push-type 支持

```
iOS 客户端                                  服务器端
──────────────────────────                 ──────────────────────────
Phase 1: 项目骨架 & 数据层 ✅             S1: 项目骨架                  ✅
    ↓                                          ↓
Phase 2: Bark 推送管线 + Agent 路由         S2: 设备注册 + KV           ✅
    ↓                                          ↓
Phase 3: Agent Dashboard + 详情页 UI       S3: APNs 推送核心           ✅
    ↓                                          ↓
Phase 4: 多服务器 + 搜索                   S4a: V0.3 字段透传 + health ⏳
    ↓                                          ↓
                  V1.0 Candidate / Release
    ↓
Phase 5: Live Activity + Widget            S4b: Live Activity push     ⏳
Phase 6: 设备端 LLM 总结                    S5: 部署 & CI               ⏳
    ↓
                  V1.1
    ↓
Phase 7: 备忘录 + Share Extension + Siri
    ↓
                  V1.2
```

**依赖**：iOS Phase 2 端到端验证依赖 Server S3（已完成）；v0.3 字段端到端验证依赖 Server S4a（待做）；Phase 5 Live Activity 远程更新依赖 Server S4b（待做）。

---

# iOS 客户端实施计划

## Phase 1: 项目骨架与数据层 ✅ **(2026-04-20 完成)**

**目标**：工程可编译，数据层可用，App Group 共享就绪。

### 关键任务

| ID | 状态 | 任务 |
|----|:---:|------|
| 1.1 | ✅ | Xcode 多 target 工程（App / NSE / Share / Widgets） |
| 1.2 | ✅ | SPM package 结构（Models / BarkService / Store / MemoKit / DesignSystem） |
| 1.3 | ✅ | App Group `group.com.barkmate.shared` |
| 1.4 | ✅ | SwiftData schema v1（原 Item 中心设计） |
| 1.5 | ✅ | ModelContainer 共享 |
| 1.6 | ✅ | 索引定义（iOS 18 #Index） |
| 1.7 | ✅ | Keychain Access Group |
| 1.8 | ✅ | Schema Migration 骨架 |
| 1.9 | ✅ | 基础 DI 配置 |
| 1.10 | ✅ | CI 配置 |

### V0.3 对 Phase 1 产出的影响

⚠️ **Phase 1 当时基于 v0.2 设计实现了 Item 中心 schema**。v0.3 改为 AgentTask + AgentStep + Memo 三表。由于 Phase 1 还**没有任何用户数据**，处理方式：

> **直接覆盖 V1 schema 定义，不做迁移。** 在 Phase 2 启动时一并完成 schema 替换，作为 Phase 2 的前置任务（见 Phase 2 任务 2.0）。

### Phase 1 收尾遗留（不阻塞 Phase 2，但需 Phase 2 启动时补）

- [ ] Info.plist 加 `AppIdentifierPrefix: $(AppIdentifierPrefix)`
- [ ] Simulator 端到端验真：App Group 跨进程读写 + Keychain access-group 共享
- [ ] git init 仓库、首次 push 触发 CI

---

## Phase 2: Bark 推送管线 + Agent 路由

**目标**：能收到 Bark 推送，按 `agent_status` 字段路由到 Agent 路径或 Message 路径，AgentTask 卡片在主应用实时可见。

**协议语义对齐 product.md**：不带 v0.3 新字段的存量 Bark 推送仍可零改动接入，但作为普通消息进入 History Timeline；只有带 `agent_status` 的推送才进入 Agent Dashboard 并聚合为状态卡片。

### 关键任务

| ID | 任务 | 说明 |
|----|------|------|
| 2.0 | **Schema 重构** | 替换 v0.2 的 Item 中心 schema 为 AgentTask + AgentStep + Memo 三表（见 design §4.1）。BarkMateSchemaV1 重新定义，不需迁移（无数据） |
| 2.1 | APNs 注册 | 获取 device token，通过 BarkClient 上报到服务器（沿用 v0.2） |
| 2.2 | BarkClient.register() | POST `/register` 接口 |
| 2.3 | NSE 入口 | `didReceive(_:withContentHandler:)` |
| 2.4 | DecryptProcessor | CryptoSwift AES-128/192/256 × CBC/ECB/GCM |
| 2.5 | PushParser | 解析 Bark 标准字段 **+ v0.3 新字段（agent_status / task_id / progress / eta）**；`group` 映射为 `agent_id`，`task_id` 缺省时按 `agent_id` 聚合 |
| 2.6 | **AgentRouter** | 判断 payload 走 Agent 路径还是 Message 路径 |
| 2.7 | **AgentTaskStore.upsert()** | 按 `aggregateKey = agentID::taskID` upsert AgentTask + insert AgentStep |
| 2.8 | ArchiveProcessor (Message 路径) | 无 `agent_status` 的旧 Bark 推送 → 保存为普通消息卡片，进入 History Timeline，不创建 AgentTask |
| 2.9 | Darwin Notification | NSE → 主应用通知 |
| 2.10 | EnrichProcessor | 图片下载、图标、提示音 |
| 2.11 | PresentProcessor | 修改 UNMutableNotificationContent |
| 2.12 | PendingQueue 扩展 | 增加 archiveStep / startLiveActivity / endLiveActivity 类型 |
| 2.13 | 主应用 Darwin 监听 | @Query 刷新 |
| 2.14 | 降级策略 | 解密失败存密文、图片失败存 URL |

### 完成标准

- [ ] 端到端测试：curl 推送（带 `agent_status=running`）→ 设备收到通知 → AgentTask upsert / AgentStep insert 正确
- [ ] 聚合测试：同一 `agent_id + task_id` 多次推送 → 只产生一张 AgentTask 卡片，AgentStep 数量等于推送次数
- [ ] 旧协议兼容：不带 `agent_status` 的推送 → 不创建 AgentTask，进 History Timeline 普通消息卡片
- [ ] 加密推送：AES-256/CBC 加密的 v0.3 payload 解密后字段解析正确
- [ ] Extension 内存：处理带图片的 agent 推送 < 24MB
- [ ] 主应用实时刷新：NSE 写入后 1 秒内 Dashboard 看到新卡片

### 风险

- **AgentTask upsert 的并发**：同一 task 短时间多次推送可能产生竞态，需要 NSE 内做唯一索引约束 + 串行化
- **CryptoSwift 在 Extension 中的二进制体积** 影响启动速度（v0.2 风险延续）

---

## Phase 3: Agent Dashboard + 详情页 UI

**目标**：核心用户流程可用——主屏看到 active agents 网格，点击进详情看 step 历史。

### 关键任务

| ID | 任务 | 说明 |
|----|------|------|
| 3.1 | AgentDashboardView | 主 Tab：状态摘要栏 + Active Agents 网格 + History Timeline |
| 3.2 | AgentCard | 卡片：图标 + 名称 + StatusBadge + 进度 + 最新 step 标题 + 时间 |
| 3.3 | StatusBadge | 六色状态徽章（design §8.3） |
| 3.4 | 全局状态摘要栏 | `N running · M waiting · K blocked` 计数 |
| 3.5 | AgentDetailView | 当前状态 + 进度 + step 历史时间线 |
| 3.6 | StepRow | 单 step 卡片（状态徽章 + 时间 + title + body 预览） |
| 3.7 | "总结进度" 按钮 | 占位（Phase 6 接入 FoundationModels） |
| 3.8 | History Timeline | 已归档 agent + Memo 混合时间线（下半屏） |
| 3.9 | MemoCard | 备忘录卡片（暂只读，Phase 7 接入编辑） |
| 3.10 | Swipe Action | 卡片上的置顶 / 归档 / 静音 / 标记完成 |
| 3.11 | StatusEngine | Stale 超时 reconcile（design §8.2） |
| 3.12 | 下拉刷新 | 处理 pending queue + 触发 reconcile |
| 3.13 | 空状态引导 | 无数据时展示 hook 接入示例 + 复制 curl 模板 |
| 3.14 | Markdown 渲染 | MarkdownView 渲染 step body（禁 HTML） |

### 完成标准

- [ ] Dashboard 滚动流畅（>50 个 agent 卡片 fps > 50）
- [ ] Agent 状态变化（NSE 推送）→ 主屏卡片 < 500ms 内更新
- [ ] Stale reconcile：30 分钟未更新的 running task 变 stale 灰化
- [ ] 详情页 step 历史正确按时间序展示
- [ ] 空状态引导文案 + curl 示例可复制

### 风险

- **AgentCard 的 SwiftUI 重渲染成本**：状态频繁更新时需要 Equatable 优化
- **History timeline 的混合数据源**：AgentTask（已归档）+ Memo 联合查询需要测试性能

---

## Phase 4: 多服务器 + 搜索

**目标**：多服务器配置可用，跨 AgentTask / AgentStep / Memo 的全文搜索可用。P0 闭环。

### 关键任务

| ID | 任务 | 说明 |
|----|------|------|
| 4.0 | FirstLaunch / Onboarding | 欢迎页 → 选择默认服务器 `api.day.app` 或添加自定义服务器 → 注册 APNs → 进入空 Dashboard |
| 4.1 | ServerListView | 服务器列表 + 状态指示器 |
| 4.2 | AddServerView | URL + Key + 名称输入；支持每服务器 key 管理 |
| 4.3 | QR 扫描（P2 / 可选） | AVCaptureSession；不阻塞 V1.0 |
| 4.4 | BarkClient 健康检查 | `/ping` |
| 4.5 | CryptoConfig 配置页 | 每服务器算法 / 模式 / 密钥（写 Keychain） |
| 4.6 | 分组静音管理 | 设置页 |
| 4.7 | SearchEngine | 三表联合搜索（agents / steps / memos 标题、正文、标签），SearchScope 控制范围 |
| 4.8 | SearchView | 搜索框 + scope chips + 结果列表 |
| 4.9 | 结果高亮 | NSAttributedString |
| 4.10 | 搜索历史 | 最近 10 次 |
| 4.11 | 日期范围 + 状态 + agent + server 过滤 | Chip 组（替代 v0.2 的"按类型过滤"） |
| 4.12 | Stale 超时阈值设置 | UserDefaults，默认 30 分钟 |
| 4.13 | CurlTemplateBuilder | 基于当前 server/key 生成可复制 hook 示例，支持 v0.3 字段模板 |
| 4.14 | 通知权限 / APNs 降级态 | 未授权、注册失败、服务器不可达时展示可恢复状态 |

### 完成标准

- [ ] 首次启动：欢迎页 → 默认服务器或自定义服务器 → APNs 注册 → 空 Dashboard + curl 模板
- [ ] 添加服务器 → APNs 注册 → 状态变绿
- [ ] 加密配置：设置密钥后加密推送可解密
- [ ] 搜索性能：每表 10k 条目下 query < 300ms（三表联合）
- [ ] 组合过滤：scope + 日期 + 状态 + agent + server 同时生效
- [ ] 失败态：通知未授权 / APNs 注册失败 / 服务器不可达均有明确 UI 状态与重试入口

### 风险

- **三表联合搜索的合并去重逻辑**：需要 SearchResult 统一包装、updatedAt 排序
- **中文 `localizedStandardContains` 分词** 效果延续 v0.2 风险

---

## Phase 5: Live Activity + Widget

**目标**：active agent 可在 Dynamic Island / 锁屏直观感知；主屏 Widget 上线。

### 关键任务

| ID | 任务 | 说明 |
|----|------|------|
| 5.1 | LiveActivityExtension target | 新 Extension target + entitlements |
| 5.2 | AgentActivityAttributes | ContentState 定义（design §9.1） |
| 5.3 | ActivityCoordinator (主 app 侧) | 启动 / 更新 / 结束 Activity |
| 5.4 | LiveActivityProcessor (NSE 侧) | `done` / `failed` / `blocked` / `waiting_input` 时触发显著通知并 end Activity；`running` 时 update |
| 5.5 | Push token 上报 | activity.pushTokenUpdates → App Group → 上报 server |
| 5.6 | Dynamic Island 展示 | compact / minimal / expanded 三种形态 |
| 5.7 | 锁屏 LA 视图 | StatusBadge + 进度 + ETA |
| 5.8 | Active Agents Widget (中/大) | 主屏 Widget，显示前 N 个 active agent |
| 5.9 | 状态摘要 Widget (小) | running / waiting / blocked 计数 |
| 5.10 | Widget Timeline Provider | 监听 App Group 数据变化触发刷新 |
| 5.11 | 锁屏 Widget (iOS 17+) | active 计数 |
| 5.12 | 快速备忘录 / 控制中心 Widget（后续） | 依赖 Phase 7 备忘录能力，不阻塞 V1.1 的 agent 状态 Widget |

### 完成标准

- [ ] LA：running + eta 推送 → Dynamic Island 显示进度
- [ ] LA：done/failed/blocked/waiting_input 推送 → LA 闭合 + 显著通知
- [ ] 远程 LA 更新：server 发 LA push → iOS 不经过 NSE 直接更新 Activity
- [ ] Widget：active agent 数量变化 → Widget 5 分钟内刷新
- [ ] 锁屏 Widget 显示正确

### 风险

- **NSE 无法直接 `Activity.request`**：依赖 server 发 `liveactivity` push type；首发可降级为"主 app 在台时启动 LA"
- **LA 8h 时间上限**：超长 task 会被系统终止，需要降级策略（v1 可接受）

---

## Phase 6: 设备端 LLM 进度总结

**目标**：用 Apple Intelligence FoundationModels 实现 agent step 历史的本地化摘要，与 Phase 5 共同组成 V1.1。

### 关键任务

| ID | 任务 | 说明 |
|----|------|------|
| 6.1 | FoundationModels 接入 | `import FoundationModels` + `@available(iOS 18.1, *)` 包装 |
| 6.2 | SummaryEngine | `summarize(task:) async throws -> String`（design §10.1） |
| 6.3 | Prompt 模板 | step 历史结构化拼接 + 摘要指令 |
| 6.4 | 可用性检测 | `SystemLanguageModel.availability` 检查 |
| 6.5 | 缓存机制 | `lastSummary` + `lastSummaryAt` 写回 AgentTask，5 分钟缓存 |
| 6.6 | UI 接入 | AgentDetailView "总结进度" 按钮接 SummaryEngine |
| 6.7 | 降级 UI | 不支持设备隐藏按钮，直接显示原始 step 列表 |
| 6.8 | 敏感字段 strip | prompt 构造时移除 server URL / Bearer token / key |

### 完成标准

- [ ] iOS 18.1 + 支持机型上，"总结进度" 按钮可点击，3 秒内返回 ≤3 句中文摘要
- [ ] iOS 17 / 不支持机型：按钮隐藏，显示原始 step 列表，无 crash
- [ ] 缓存：5 分钟内无新 step 时复用 lastSummary，不重复推理
- [ ] Prompt 不含敏感字段（单元测试覆盖）

### 风险

- **FoundationModels API 演进**：API 仍可能变更，需在 beta 阶段密切跟进
- **设备覆盖率**：Apple Intelligence 仅支持 iPhone 15 Pro+ 和 iOS 18，V1.1 实际可用用户比例需要监控

---

## Phase 7: 备忘录 + Share Extension + Siri

**目标**：交付 V1.2 的备忘录与 Share Extension；Siri / App Intents 作为 P2 增强随 V1.2 收尾。

### 关键任务

| ID | 任务 | 说明 |
|----|------|------|
| 7.1 | MemoEditor | Markdown 编辑器 + 预览 |
| 7.2 | TagParser | 行内 `#tag` 提取 |
| 7.3 | DraftManager | 草稿自动保存到 UserDefaults |
| 7.4 | PhotosPicker + FileImporter | 附件选择 |
| 7.5 | Memo 创建入口 | History Timeline 顶部 "+" 按钮（不再是主屏 FAB） |
| 7.6 | ShareExtension target | SLComposeServiceViewController / 自定义 UI |
| 7.7 | Share 类型支持 | 文本 / URL / 图片 |
| 7.8 | LPLinkMetadata | URL 元数据（可选） |
| 7.9 | Toast 反馈 | Share 后极简确认 UI |
| 7.10 | AppIntents | "在 BarkMate 保存一条备忘" / "查询 active agent 数量" |
| 7.11 | Siri Shortcuts | App Intents 集成 |

### 完成标准

- [ ] 创建 Memo → History timeline 即时可见
- [ ] 草稿恢复：杀进程重启能恢复未保存内容
- [ ] Safari 分享链接 → 出现新 Memo
- [ ] Share Extension 内存 < 24MB
- [ ] Siri 语音 "在 BarkMate 保存一条备忘" 可触发

---

# 服务器端实施计划 (BarkMateServer)

> 代码位置：`BarkMateServer/`。S1-S3 已完成（MS1 达成）。后续拆为 V1.0 必需的 S4a 与 V1.1 的 S4b。

## S1: 项目骨架 ✅

完成于 2026-04-20。

## S2: 设备注册 + KV 存储 ✅

完成于 2026-04-20。

## S3: APNs 推送核心 ✅

完成于 2026-04-20。`barkmate.we2.xyz` 部署，JWT + APNs 签名通过验证。

## S4a: V0.3 字段透传 + Health Endpoints（V1.0 必需）

**目标**：`/push` 接受并透传 v0.3 新字段；提供客户端多服务器健康检查所需端点。

| ID | 任务 | 说明 |
|----|------|------|
| S4a.1 | PushMessage 类型扩展 | 增加可选 `agent_status` / `task_id` / `progress` / `eta` |
| S4a.2 | APNs payload 构造 | 把 v0.3 字段以小写键透传到 `aps` 同级 |
| S4a.3 | 单元测试 | 含 v0.3 字段的 payload 序列化正确 |
| S4a.4 | `GET /ping` / `/healthz` / `/info` | 支持客户端健康检查、版本展示、server capability 检测 |
| S4a.5 | Bearer auth (可选) | env `BARKMATE_AUTH_TOKEN`；关闭时保持 Bark 兼容 |

**完成标准**
- [ ] curl 推送含 `agent_status=running&progress=3/7` → iOS 收到时字段完整
- [ ] `/ping` / `/healthz` / `/info` 可被客户端用于 server 状态展示
- [ ] Bearer auth 开启时拒绝未授权请求，关闭时不影响 Bark 老协议兼容

## S4b: Live Activity Push 支持（V1.1）

**目标**：新增 Live Activity push 端点，支持 ActivityKit 远程更新。

| ID | 任务 | 说明 |
|----|------|------|
| S4b.1 | `POST /liveactivity/:token` | 接收 LA push token + content state，发 push-type: liveactivity |
| S4b.2 | LA JWT 处理 | 同 APNs JWT 复用 |
| S4b.3 | LA push payload | `aps.content-state` + `aps.event` (`update` / `end`) |
| S4b.4 | LA token 生命周期 | 接收 invalidation → 清除 |
| S4b.5 | LA 频率控制 | server 端 debounce，避免过高频远程更新 |

**完成标准**
- [ ] LA push 端点：iOS 上报 token → server 发 LA push → Dynamic Island 更新

## S5: 部署 & CI

复用 v0.2 计划：

| ID | 任务 |
|----|------|
| S5.1 | `wrangler.toml` 多环境 |
| S5.2 | `.github/workflows/deploy.yml` |
| S5.3 | Secrets 文档 |
| S5.4 | 自定义域名 |
| S5.5 | 监控接入（可选） |
| S5.6 | README |

## 技术风险汇总（服务器端）

| 风险 | 等级 | 缓解 |
|------|------|------|
| Workers CPU 50ms 限制（免费） | 中 | 付费计划 30s / APNs <100ms |
| LA push 频率限制 | **新** 中 | Apple 文档要求合理频率，server 端 debounce |
| KV 最终一致性 | 低 | 同区域读写 < 1s |
| APNs JWT 算法兼容 | 中 | ES256 = ECDSA P-256，Workers 原生支持 |
| p8 secret 泄漏 | 高 | Wrangler secret / 不进 git / 可作废重签 |

---

## V1.0 发布检查清单

- [ ] Phase 2-4 完成标准全部通过（Phase 5/6/7 在 V1.1/V1.2，不阻塞 V1.0）
- [ ] Server S4a 完成（v0.3 字段透传 + health endpoints）；S4b Live Activity 不阻塞 V1.0
- [ ] 代码覆盖率 > 70%（核心 BarkService / AgentKit / Store 包）
- [ ] 迁移测试：V1 schema 创建的 store 可被新版加载（无外发版本则跳过）
- [ ] 内存基准：App < 80MB，Extension < 24MB
- [ ] 性能基准：冷启动 < 1.5s（iPhone 14 基准）
- [ ] 隐私边界：除 APNs 注册和 Bark server 通信外无额外网络请求
- [ ] App Store 合规：权限描述（通知、相机、照片）
- [ ] 隐私政策文档
- [ ] Demo 视频 + 截图
- [ ] TestFlight 内测 > 7 天，关键 bug 清零

## 里程碑

| 里程碑 | 范围 | 退出标准 | 实际 |
|--------|------|----------|------|
| **M1** | iOS Phase 1 完成 | 数据层 & App Group 稳定 | ✅ **2026-04-20** |
| **MS1** | Server S1-S3 完成 | curl 通过自建 server 推真机 | ✅ **2026-04-20** |
| **M2** | iOS Phase 2 完成 | Agent 路由 + upsert + 推送管线 E2E | — |
| **M3** | iOS Phase 3 完成 | Dashboard + 详情页可演示 | — |
| **M4** | iOS Phase 4 完成 | P0 闭环（多服务器 + 搜索）→ **V1.0 候选** | — |
| **MS2a** | Server S4a 完成 | v0.3 字段透传 + health endpoints → **V1.0 server ready** | — |
| **M5** | V1.0 Release | Phase 2-4 + S4a 完成，App Store 上架 | — |
| **MS2b** | Server S4b 完成 | Live Activity push 支持 → **V1.1 server ready** | — |
| **M6** | iOS Phase 5 完成 | Live Activity + Widget → **V1.1 组成部分** | — |
| **M7** | iOS Phase 6 完成 | 设备端 LLM 总结 → **V1.1 Feature Complete** | — |
| **M8** | iOS Phase 7 完成 | 备忘录 + Share + Siri → **V1.2 Feature Complete** | — |

> **注**：V1.0 上架仅需 iOS Phase 2-4 + Server S4a。Phase 5/6 作为 V1.1，Phase 7 作为 V1.2 后续更新。

## 并行机会

- Phase 2 进行时，Phase 3 的 UI 可基于 mock 数据并行开发
- Phase 4 SearchEngine 可从 Phase 3 开始时并行
- Phase 5 Widget 可独立于 Live Activity 并行
- DesignSystem 组件可在 Phase 1 之后任何时点开始
- Server S4a 可与 iOS Phase 2-3 并行（只要 v0.3 字段约定先冻结）
- Server S4b 可与 iOS Phase 5 并行，但不阻塞 V1.0

## 技术风险汇总

| 风险 | 等级 | 缓解 | 现状 |
|------|------|------|------|
| AgentTask upsert 并发竞态 | **新** 高 | 唯一索引 + NSE 内串行化 + 失败重试 | ⏳ Phase 2 验证 |
| Extension 内存超限 | 高 | 每 Phase 内存测试 | ⏳ Phase 2 实测 |
| Live Activity 远程更新依赖 server | **新** 中 | Phase 5 启动前 S4b 必须达成；不阻塞 V1.0 | ⏳ |
| FoundationModels API 演进 | **新** 中 | 跟进 iOS 18 beta；预留降级路径 | ⏳ Phase 6 |
| SwiftData 多进程写冲突 | 中 | WAL + 短事务 | ✅ Phase 1 验过 |
| CryptoSwift 性能 | 低 | 单次推送数据量小 | ⏳ Phase 2 |
| 中文搜索效果 | 中 | V1 LIKE 方案 / V2 FTS5 | ⏳ Phase 4 |
| Apple Intelligence 设备覆盖率 | **新** 中 | 监控可用用户比例；不可用时优雅降级 | ⏳ Phase 6 |
