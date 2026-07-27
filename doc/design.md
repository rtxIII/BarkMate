# BarkAgent — 技术设计

> 版本: 0.5.0 | 日期: 2026-07-22 | 状态: Draft（glance-first 重构 · 配合 product.md v0.5.0）

## 0. 本次修订（v0.3 文档 → v0.5，对齐真身代码）

v0.3 design 文档描述的是绿地设想，与当前**真实代码库 `BarkMate/`** 已脱节。v0.5 做两件事：**(1) 把文档校正到真身**，**(2) 注入 glance-first 三条工作线**。

### 0.1 文档 vs 真身校正表

| v0.3 文档写的 | 真身代码（`BarkMate/`，git HEAD） | v0.5 处置 |
|---------------|-----------------------------------|-----------|
| 最低 iOS 17 | project.yml `deploymentTarget.iOS: 18.0` | 改为 iOS 18 |
| 模块 `AgentKit` / `ActivityKit-Wrapper` / `LiveActivityExtension` | **均不存在**；LA 仅 `AgentTask.liveActivityID` 字段 + Models 内 ActivityAttributes 空壳 | 删虚构模块；LA UI **并入现有 `BarkMateWidgets` bundle**（不新开 target），本地链 **P0** / 远程冷态 P1 |
| App Group `group.com.barkmate.shared` | 实际 `group.com.barkagent.shared` | 改真值 |
| 4 Tab 含 Search、Memo（P1） | Search Tab 已删（commit `e55d988`）；Memo 概念下线（`AgentInboxItem` 仅承载旧协议 incoming） | 清账；不回收 |
| 8 段 Processor 管线（NSE 内联） | 抽为纯函数 `PushPipeline.process()`（decrypt→parse→archive→degrade），NSE 是薄壳 | 按真身描述 |
| `Item` → 三表迁移 | 已完成，`BarkAgentSchemaV1` = 六实体，无 migration stage | 标为已落地 |

### 0.2 三条工作线（对应 product.md 三句抱怨）

| 线 | 治什么 | 核心动作 | 优先级 |
|----|--------|----------|--------|
| **线 A · Glance 新鲜度** | "状态变 UI 不动" | NSE 落库后**立即** `WidgetCenter.reloadTimelines`；主 app 侧 upsert 后同刷 | **P0** |
| **线 B · IA 瘦身** | "信息太多" | 3 Tab → 2 Tab；History 折入 Agents 的 Settled 段 | **P0** |
| **线 C · Live Activity** | "离桌感知" 深化 | **本地链（P0）**：LA UI 并入现有 `BarkMateWidgets` bundle + 主 app 起/更/闭 LA + NSE update 已存在 LA。**远程冷态（P1）**：app 被杀时 server LA push 更新 | **P0（本地）/ P1（远程）** |

> **根因诊断（file:line 级）**：全工程**无任何** `WidgetCenter.reloadTimelines` 调用（`BarkMateWidgets.swift:11` 仅有一句"由主 app 触发"的注释，代码未实现）。NSE 已直接写 SwiftData（数据新鲜），但 glance 表面无人捅，只能靠 Widget 10 分钟轮询或 app 打开追平。这是"不即时"的确切病根，也是线 A 的最小闭环落点。

## 1. 架构概览

BarkAgent 是基于现代 Apple 框架构建的原生 iOS 应用。V0.5 的重心从「app 内 dashboard」下移到「glance 表面」，数据管道不变，新增"推送到达即刷 glance"的旁路。

```
┌─────────────────────────────────────────────────────────────────┐
│                        App Targets                              │
├──────────────┬──────────────────────┬───────────────┬──────────┤
│  BarkMate     │ NotificationService  │ BarkMateWidgets│ LiveAct. │
│  (main app)  │ Extension (NSE)      │  (Widget)     │ Ext (P1) │
├──────────────┴──────────────────────┴───────────────┴──────────┤
│              App Group: group.com.barkagent.shared               │
│  ┌────────────────────────────────────────────────────────┐    │
│  │           SwiftData ModelContainer (shared)            │    │
│  │  AgentTask · AgentStep · AgentInboxItem                │    │
│  │  Resource · Server · CryptoConfig                      │    │
│  └────────────────────────────────────────────────────────┘    │
│  UserDefaults(suite) · Keychain(access group) · PendingQueue    │
└─────────────────────────────────────────────────────────────────┘
      │ Darwin: itemDidArrive          │ WidgetCenter.reloadTimelines
      ▼ (刷新主 app Dashboard)          ▼ (刷新 Widget · 线 A 新增)
   ┌───────────┐   ┌──────────────┐   ┌──────────────────┐
   │ APNs      │   │ Bark Server  │   │  FoundationModels │
   │ (Apple)   │   │ (HTTP API)   │   │  (on-device, P1) │
   └───────────┘   └──────────────┘   └──────────────────┘
```

## 2. 技术栈（真身）

| 层级 | 技术 | 备注 |
|------|------|------|
| UI | SwiftUI | 主 app 自管 tab（ZStack + MCTabBar，非系统 TabView） |
| 数据 | SwiftData | `BarkAgentSchemaV1` 六实体；App Group 共享 store |
| 并发 | Swift Concurrency | `SWIFT_STRICT_CONCURRENCY: complete`（Swift 6 严格模式） |
| 网络 | URLSession | `BarkClient` 注册 & push |
| 加密 | CryptoKit + CryptoSwift | Bark AES 兼容（CBC/ECB/GCM） |
| Markdown | swift-markdown-ui (`MarkdownUI`) | 详情/正文渲染 |
| DI | Factory `2.5.0+` | `Container+App` / `Container+Extension` |
| Widget | WidgetKit | glance 层核心（线 A） |
| Live Activity | ActivityKit | P1 新增 target |
| 设备端 LLM | FoundationModels | iOS 18.1+，P1 |
| 最低目标 | **iOS 18.0** | project.yml deploymentTarget |

### 依赖管理

XcodeGen（`project.yml`）+ 本地 SPM Packages：

```
Packages（本地）:
├── Models        # SwiftData 实体 + 枚举 + Schema
├── BarkService   # 推送管线（decrypt/parse/archive/route）
├── Store         # 数据访问 + App Group + Keychain + Darwin + 各类 Store
└── DesignSystem  # MissionControl 设计语言 + MC 组件

远程依赖:
├── Factory (DI)
└── MarkdownUI (swift-markdown-ui)
```

## 3. 模块架构（真身）

```
BarkMate/
├── App/                              # 主应用 target
│   ├── Sources/
│   │   ├── BarkMateApp.swift / AppDelegate.swift
│   │   ├── PushRegistrar.swift / PushRegistrar / PendingQueueDrainer
│   │   ├── DI/Container+App.swift
│   │   └── Views/
│   │       ├── MainTabView.swift        # 2 Tab（v0.5：删 History tab）
│   │       ├── AgentDashboardView.swift  # 三桶 triage + project 分组折叠
│   │       ├── AgentDetailView.swift     # step 历史 + 摘要（P1）
│   │       ├── HistoryView.swift         # v0.5：内容折入 Dashboard，view 保留供过渡
│   │       ├── SettingsView.swift / SetupView.swift
│   │       ├── ServerListView.swift / AddServerView.swift
│   │       ├── AlertSoundPickerView.swift / StaleTimeoutPickerView.swift
│   │       └── ContentView.swift
│   ├── Tests/BarkMateTests/          # 单测（Dashboard mapping / SelectedTab / 等）
│   └── UITests/BarkMateUITests/      # UI 测试
│
├── Packages/
│   ├── Models/Sources/Models/
│   │   ├── AgentTask.swift + AgentTask+Stale.swift   # effectiveStatus 派生 stale
│   │   ├── AgentStep.swift
│   │   ├── AgentInboxItem.swift      # 旧协议 incoming（[BARK] 徽章）
│   │   ├── Resource.swift / Server.swift / CryptoConfig.swift
│   │   ├── Enums.swift               # AgentStatus / BodyType / ...
│   │   └── SchemaV1.swift            # BarkAgentSchemaV1 + MigrationPlan（空 stage）
│   │
│   ├── BarkService/Sources/BarkService/
│   │   ├── PushPipeline.swift        # 纯函数 entry：process(userInfo:bundle:container:)
│   │   ├── PushParser.swift          # ParsedPush（Bark 标准 + v0.3 新字段）
│   │   ├── DecryptProcessor.swift    # AES 解密 + 降级
│   │   ├── AgentRouter.swift         # agent vs inbox 路由
│   │   ├── PushArchiver.swift        # upsert AgentTask + insert AgentStep / archiveInboxItem
│   │   ├── PendingQueue.swift        # 落库失败降级队列
│   │   ├── AlertSoundResolver.swift  # per-status 声音决策
│   │   ├── ImageEnricher.swift       # 图片附件下载
│   │   ├── DemoPushInjector.swift    # demo 推送注入（Dashboard/Setup 共用）
│   │   ├── BarkClient.swift + BarkClientProtocol.swift + BarkAPIError.swift
│   │   ├── CryptoBundle.swift + CryptoSettingsStore.swift
│   │   ├── DeterministicID.swift + SearchEngine.swift
│   │   └── BarkService.swift
│   │
│   ├── Store/Sources/Store/
│   │   ├── SharedModelContainer.swift  # App Group 内共享容器
│   │   ├── AppGroup.swift              # "group.com.barkagent.shared"
│   │   ├── DarwinNotification.swift    # itemDidArrive / pendingTaskQueued
│   │   ├── KeychainService.swift
│   │   ├── StaleTimeoutStore.swift     # stale 阈值持久化
│   │   ├── AlertSoundStore.swift + SoundCatalog.swift
│   │   ├── DeviceTokenStore.swift + NotificationStatus.swift
│   │   └── DraftManager.swift
│   │
│   └── DesignSystem/                   # MissionControl 设计语言 + MC* 组件
│
├── NotificationServiceExtension/       # 薄壳：PushPipeline + 图片 + Darwin（+ 线 A reloadTimelines）
│   └── Sources/NotificationService.swift + DI/Container+Extension.swift
│
└── Widgets/Sources/BarkMateWidgets.swift  # ActiveAgentsWidget（small/medium/+accessory 锁屏）
                                           # + AgentLiveActivity（线 C：LA 并入此 bundle，不新开 target）
```

## 4. 数据模型（真身 · BarkAgentSchemaV1）

### 4.1 实体清单

`Models/SchemaV1.swift` 定义 `BarkAgentSchemaV1`（版本 1.0.0，无 migration stage，应用未发布无用户数据）：

- **AgentTask** — 持久 agent 卡片（Dashboard 一等公民）
- **AgentStep** — 单次推送快照（`AgentTask.steps` 反向关系）
- **AgentInboxItem** — 旧协议 incoming 消息（无 `agent_status`）
- **Resource** — 附件（关联 step 或 inboxItem）
- **Server** — Bark 服务器
- **CryptoConfig** — 加密配置

### 4.2 AgentTask（核心）

真身字段（`Packages/Models/Sources/Models/AgentTask.swift`）：

```swift
@Model public final class AgentTask {
    #Index<AgentTask>(
        [\.aggregateKey],                 // upsert 主路径
        [\.isArchived, \.updatedAt],      // Dashboard 主查询
        [\.statusRaw, \.updatedAt],       // 状态过滤
        [\.isPinned, \.updatedAt]
    )
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var aggregateKey: String   // "<agentID>::<taskID-or-_>"
    var agentID: String
    var taskID: String?
    var displayName: String
    var iconURL: String?
    var statusRaw: String                 // AgentStatus.rawValue（存 raw，避枚举迁移坑）
    var latestStepTitle: String?
    var progress: String?
    var eta: Date?
    var isPinned, isArchived, isMuted: Bool
    var sourceServerID: UUID?
    var liveActivityID: String?           // 线 C：关联 ActivityKit id
    var lastSummary: String?              // 线 P1：LLM 摘要缓存
    var lastSummaryAt: Date?
    var createdAt, updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \AgentStep.task) var steps: [AgentStep]
}
```

- `status` 是 `statusRaw` 的 computed 包装。
- `aggregateKey(agentID:taskID:)` 静态方法生成聚合键（`taskID` 为 nil 时用 `_` 占位）。

### 4.3 派生 Stale（AgentTask+Stale.swift）

**关键设计**：stale 不落库，是**渲染时按 now 惰性计算**的派生态：

```swift
func effectiveStatus(now: Date, threshold: TimeInterval) -> AgentStatus
// running 且 (now - updatedAt) > threshold → .stale；其余原样返回
```

- 阈值来自 `StaleTimeoutStore.threshold()`（**默认 15 分钟**，Settings 可调）。真身 `StaleThresholdCatalog.defaultThreshold = .minutes(30)` 且 `options = [off,10,30,60,120]` —— v0.5 落地需插入 `.minutes(15)` 并改默认为 15（见 plan.md G1）。
- Dashboard / History 渲染各自调 `effective(_:)`，不写回 `statusRaw`——避免多进程写竞争，也保证阈值改动即时生效。

### 4.4 枚举（Enums.swift）

```swift
enum AgentStatus: String { case running, waitingInput = "waiting_input",
                                blocked, done, failed, stale }
enum BodyType: String { case plainText, markdown }
```

- `AgentStatus.mcBucket` → `.needsYou` / `.running` / `.settled`（Dashboard/Widget 分桶共用）。
- `isTerminal`：`done` / `failed`。

## 5. App Group 共享策略

**App Group: `group.com.barkagent.shared`**（`Store/AppGroup.swift`）。主 app / NSE / Widget（Widget bundle 内含 Live Activity）共享：

```
group.com.barkagent.shared
├── SwiftData store（SharedModelContainer.make() 统一配置）
├── UserDefaults(suite)：stale 阈值 / 通知偏好 / 声音偏好 / device token
├── Keychain（access group）：AES key / IV
└── PendingQueue（NSE 落库失败降级；主 app PendingQueueDrainer 消费）
```

### 5.1 进程间协调

| 机制 | 事件 | 用途 |
|------|------|------|
| Darwin Notification | `itemDidArrive` | NSE 落库后通知主 app 刷新 Dashboard（`DashboardContent` 靠 `refreshToken` 重建） |
| Darwin Notification | `pendingTaskQueued` | 落库失败入队，提示主 app drain |
| **WidgetCenter（线 A 新增）** | `reloadTimelines(ofKind:)` | NSE / 主 app 落库后刷新 Widget timeline |
| ActivityKit push token（线 C） | — | 主 app 拿 LA push token 上报 server |

## 6. NotificationServiceExtension 设计（真身 + 线 A）

### 6.1 现状：薄壳 + 纯函数管线

`NotificationService.didReceive` 只做 Notification 框架交互，schema 决策全在 `PushPipeline.process()`：

```
didReceive → SharedModelContainer.make() → resolve CryptoBundle
           → PushPipeline.process(userInfo:bundle:container:) → Outcome
           → applyDecrypted（明文 alert 同步回 banner）
           → applyAlertSound（per-status 声音覆写）
           → ImageEnricher.attachImageIfNeeded
           → switch Outcome: .archived/.pending → DarwinNotification.post(.itemDidArrive)
                             .dropped → 仅 log
           → contentHandler(content)
```

`PushPipeline.process()` 内部：

```
decrypt = DecryptProcessor.decryptIfNeeded(userInfo, bundle)
parsed  = PushParser.parse(decrypt.userInfo)
if container:  PushArchiver.archive(parsed, degradation: decrypt)
               → .archived(routeKind: agentStatus != nil ? .agent : .inbox)
else / 失败:   PendingQueue.enqueue → .pending / .dropped
```

`PushArchiver.archive`（`aggregateKey` fetch-then-decide upsert，符合 SwiftData `@Attribute(.unique)` 是 upsert 而非 reject 的语义）：
- **agent 路径**：fetch AgentTask by aggregateKey → 存在则更新字段 / 不存在则 insert；再按 step.id 去重 insert AgentStep（C1 修复：同 id 不重复插）。
- **inbox 路径**：fetch AgentInboxItem by id → upsert。

### 6.2 线 A：Glance 新鲜度（P0 · 本次核心改动点）

**问题**：`PushPipeline` / NSE 落库后，从不调 `WidgetCenter.reloadTimelines`。Widget 只能 10 分钟轮询。

**方案**：在 `.archived` / `.pending` 分支，**Darwin post 之后追加一次 Widget 刷新**：

```swift
// NSE processPipeline() switch outcome:
case .archived, .pending:
    DarwinNotification.post(.itemDidArrive)
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.activeAgents)  // 线 A 新增
```

设计约束与取舍：
- **放 NSE 里而非只放主 app**：NSE 是"app 未打开也会跑"的唯一入口，这是"离桌即时"的关键。主 app 侧 upsert（demo push / drain）也补一次同样调用。
- **成本可控**：`reloadTimelines` 是轻量信号，不在 NSE 24MB/30s 预算的风险区（真正耗资源的是解密/图片下载，已在前）。
- **kind 常量化**：抽 `WidgetKind.activeAgents` 常量（见 plan G1.1），NSE 与 Widget 共用，避免字符串漂移。
- **降级**：`reloadTimelines` 失败不阻断 `contentHandler`（glance 刷新是尽力而为，不影响通知呈现）。

### 6.3 资源限制（不变）

| 限制 | 值 | 应对 |
|------|-----|------|
| 内存 | ~24MB | 轻量写入；解密/图片阶段控量 |
| 执行时间 | ~30s | `serviceExtensionTimeWillExpire` 兜底交付 |
| 无 UI | — | 静默完成 |

### 6.4 降级矩阵

| 失败点 | 降级 |
|--------|------|
| 解密失败 | 存原始密文，标记 encrypted（DecryptProcessor 内） |
| 容器不可用 / 落库失败 | PendingQueue.enqueue → `.pending`；主 app drain 重放 |
| 入队也失败 | `.dropped`，仅 log，不崩 |
| Widget 刷新失败（线 A） | 忽略，不阻断通知 |
| 无 `agent_status` 旧推送 | 走 inbox 路径落 AgentInboxItem |

## 7. 数据流

### 7.1 Agent 推送流（含线 A glance 刷新）

```
Agent/Hook → curl → Bark Server → APNs → NSE
   NSE:
   ├─ PushPipeline.process → PushArchiver.upsert（SwiftData）
   ├─ WidgetCenter.reloadTimelines           ← 线 A：glance 即时刷
   ├─ DarwinNotification.post(.itemDidArrive)  → 主 app（前台时刷 Dashboard）
   └─ contentHandler（系统 banner）
   主 app 收到 Darwin:
   └─ AgentDashboardView.refreshToken &+= 1 → DashboardContent 重建 → @Query 拉最新
```

### 7.2 LLM 摘要流（P1，按需触发）

```
AgentDetailView → 用户点 "总结进度"
   → 检查 lastSummary/lastSummaryAt（≤5min 复用缓存）
   → SystemLanguageModel.availability
       available → LanguageModelSession.respond(prompt: 最近 N step title+body)
       unavailable → 隐藏按钮，纯 step 列表
   → 结果写回 task.lastSummary / lastSummaryAt
```

Prompt 构造时 strip server URL / key / auth header（安全，§12.3）。

## 8. Agent 状态机引擎

### 8.1 状态来源

客户端**完全信任 agent 推送的 `agent_status`**，不校验转换合法性。Agent 是事实来源。

### 8.2 Stale 派生（真身：不落库）

见 §4.3。相对 v0.3 文档的 `StatusEngine.reconcileStale()`（定时写库覆盖）方案，真身改为 **`effectiveStatus(now:threshold:)` 惰性派生**——更简单、无写竞争、阈值改动即时生效。

驱动时机：Dashboard / History 每次渲染按当前 `Date()` + `StaleTimeoutStore.threshold()` 计算。

### 8.3 状态 → 桶 → 色映射

| 状态 | 桶（mcBucket） | 语义 |
|------|----------------|------|
| waiting_input / blocked | needsYou | 需你插手（顶部大卡 + 优先 Live Activity） |
| running | running | 在跑 |
| done / failed / stale | settled | 已了结（含派生 stale） |

配色走 DesignSystem 的 MissionControl 色板（amber/cyan/lime 等 HUD 色）。

## 9. Live Activity 设计（线 C · 本地链 P0 / 远程冷态 P1）

> **现状**：无独立 LA target；只有 `AgentTask.liveActivityID` 字段预留（无 ActivityAttributes 空壳,G3.1 全新创建）。LA UI **并入现有 `BarkMateWidgets` bundle**（不新开 target，见 plan G3.1）。
> **拆分**：**本地链 P0**（§9.1-9.2：LA 声明进 widget bundle + 主 app 起/更/闭 LA,app 前台/活跃时即可用;NSE 进程隔离无法碰 LA,只落库+Darwin）；**远程冷态 P1**（§9.3：app 挂起/被杀时 server LA push，依赖 BarkMateServer）。

### 9.1 ActivityAttributes

```swift
struct AgentActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: AgentStatus
        var stepTitle: String
        var progress: String?
        var eta: Date?
        var updatedAt: Date
    }
    var agentID: String
    var displayName: String
    var iconURL: String?
}
```

### 9.2 生命周期与约束

| 操作 | 触发者 | 约束 | 优先级 |
|------|--------|------|--------|
| 启动 | 主 app（前/后台） | **NSE 无法 `Activity.request`**——本地首启靠主 app | **P0** |
| 更新 | **主 app（coordinator reconcile）** | **NSE 无法 update**:`Activity.activities` 进程隔离,extension 里恒为空(已验证)。本地更新只能主 app 进程,覆盖前台/活跃 | **P0** |
| 结束 | 主 app（离开 needsYou / 用户归档） | `Activity.end(dismissalPolicy: .immediate)`;同样只能主 app | **P0** |
| 远程冷态更新 | server `liveactivity` push | app 挂起/被杀时唯一通道，依赖 Server | P1 |

启动规则（方案 X，来自旧 Bark 实现经验）：
- `waiting_input` / `blocked` 的 (agentID+taskID) → 起一个 LA（最需注意的状态）
- 转 `running` / `done` / `failed` / `stale` / 用户归档 → end 对应 LA
- 保留 LA 且状态仍为 needsYou → update content state（前台链刷新）
- 同时活跃 LA 上限 cap（默认 4），超过 LRU 驱逐
- 仅 iOS 16.2+ 生效（Dynamic Island）；本 app 最低 iOS 18，无兼容负担
- **本地链边界**：`Activity.request`/`update`/`end` 全部只能主 app 进程调（`activities` 进程隔离,NSE 恒空）。app 挂起或被系统杀掉时主 app 不跑 → 冷态/后台更新走不通,必须走 §9.3 远程 push（P1）

### 9.3 远程更新 push token 流程（依赖 Server 端 · P1）

```
1. 主 app 启动 Activity → activity.pushTokenUpdates 流
2. 收到 token → 写 App Group + 上报 Bark server
3. Server 推送时若 task 有活跃 LA token → 同发 LA push（push-type: liveactivity）
4. iOS 直接更新 Activity，不经 NSE
```

> **跨端依赖**：仅"远程冷态更新"（app 被杀）需 BarkMateServer 支持 LA push 端点，列 P1。**本地链（§9.1-9.2，app 运行时的起/更/闭）不依赖 Server，列 P0**。

## 10. 设备端 LLM 摘要（P1）

### 10.1 FoundationModels 集成

```swift
@available(iOS 18.1, *)
struct SummaryEngine {
    func summarize(task: AgentTask) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.availability == .available else { throw SummaryError.unavailable }
        let session = LanguageModelSession(model: model)
        return try await session.respond(to: buildPrompt(task: task)).content
    }
}
```

### 10.2 触发与缓存

- **非自动**：AgentDetail 内手动点 "总结进度" 才调用（省功耗）。
- **缓存**：`lastSummary` + `lastSummaryAt` 写回 AgentTask；缓存有效期（默认 5min）内无新 step 复用。
- **可用性**：`SystemLanguageModel.availability` 不可用（iOS 版本/机型/用户关闭）→ 隐藏按钮，纯 step 列表。

### 10.3 隐私

Prompt/response 全 on-device；构造时 strip server URL/key/auth；输出走 Markdown 沙箱（禁 HTML）。

## 11. 搜索（真身：无独立 Tab）

Search Tab 已在 v0.4 删除。`BarkService/SearchEngine.swift` 仍在，作为**未来 Agents 内联搜索**的能力底座（不是独立入口）。v0.5 不新增 Search UI；若后续需要，挂在 Agents 顶部搜索框（product.md §7.2）。

## 12. 安全设计

### 12.1 威胁模型（沿用）

| 威胁 | V1 缓解 |
|------|---------|
| 设备丢失数据被提取 | iOS Data Protection（AFU） |
| 推送中间人 | APNs TLS + Bark E2E AES |
| 密钥泄露 | Keychain（access group，硬件保护） |
| LLM 摘要泄敏 | strip URL/key/auth；on-device |
| 恶意 server 伪造 status | UI 信任但展示来源 server；可静音 |

> 上架必备之外（Encryption 区块 / SQLCipher / 生物识别锁）**不做**（历史决策）。

### 12.2 密钥管理

```
Keychain（access group "{teamID}.com.barkagent.shared"）
├── AES Key / IV（KeychainService.Configuration.shared(teamID:)）
```

### 12.3 输入安全

- Markdown 禁 HTML；URL scheme 白名单 http/https/tel/mailto
- 图片仅 https，限大小
- LLM prompt strip 已知敏感字段

## 13. 错误处理

| 层级 | 策略 |
|------|------|
| NSE | 静默降级；PendingQueue 兜底；Widget 刷新失败忽略 |
| 数据层 | fetch-then-decide upsert；save 失败入 pending |
| 网络层 | 指数退避（BarkClient） |
| LLM 层（P1） | 不可用 fallback 列表；推理失败不缓存 + UI 提示 |
| UI 层 | 空态 / setup 引导 / 错误状态可见 |

PendingQueue 任务类型（真身以 `PendingQueue` 落 parsed push 为主；线 C 后扩 LA 启停）：
```swift
// 现状：enqueue(ParsedPush)
// 线 C 扩展预留：startLiveActivity / endLiveActivity（NSE 无法直启，交主 app）
```

## 14. Schema 迁移

`BarkAgentSchemaV1` = 六实体，`BarkAgentMigrationPlan.stages = []`（未发布无数据）。V2 扩展时新增 `SchemaV2` + migration stage。各模型预留 `metadata: Data?` 支持 lightweight migration。

## 15. 设计差异对比（v0.3 文档 → v0.5 真身）

| 维度 | v0.3 文档设想 | v0.5 真身 + 本次 |
|------|---------------|------------------|
| 最低系统 | iOS 17 | iOS 18 |
| Tab | 4（含 Search） | **2（Agents + Settings）** |
| Memo | P1 手写备忘 | 删除；`AgentInboxItem` 仅旧协议 incoming |
| NSE 结构 | 8 段内联 Processor | 纯函数 `PushPipeline` + 薄壳 NSE |
| Stale | `StatusEngine` 定时写库 | `effectiveStatus` 惰性派生（不写库） |
| Glance 新鲜度 | 未定义 | **线 A：NSE 落库即 reloadTimelines** |
| 模块 | AgentKit/LA-Wrapper/LA-Ext | 均无；LA UI 并入现有 Widgets bundle（不新开 target） |
| Live Activity | "完整集成" | 空壳；**本地链 P0 + 远程冷态 P1**（后者依赖 Server LA push） |
| 虚构模块 | 有 | 已清除，对齐真实 Packages 布局 |
