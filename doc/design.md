# BarkAgent — 技术设计

> 版本: 0.3.0 | 日期: 2026-05-08 | 状态: Draft（配合 product.md v0.3.0 重写）

## 1. 架构概览

BarkAgent 是基于现代 Apple 框架构建的原生 iOS 应用。架构遵循模块化、本地优先的设计，数据层、业务逻辑和展示层清晰分离。

V0.3 定位重写后，**Agent 状态机**成为数据层一等公民——推送进来后不只是塞进消息表，还要按 `agent_id + task_id` 聚合更新 `AgentTask` 卡片。

```
┌─────────────────────────────────────────────────────────────────┐
│                        App Targets                              │
├──────────┬──────────────┬─────────────┬────────────┬───────────┤
│ BarkAgent │ Notification │   Share     │  Widgets   │ LiveAct.  │
│ (main)   │ Service Ext  │ Extension   │ (Agent/    │ Extension │
│          │              │             │  Memo)     │           │
├──────────┴──────────────┴─────────────┴────────────┴───────────┤
│                    App Group (shared)                            │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              SwiftData ModelContainer                  │    │
│  │  ┌──────┐ ┌──────────┐ ┌──────────┐ ┌──────┐ ┌──────┐ │    │
│  │  │Agent │ │AgentStep │ │  Memo    │ │Server│ │Crypto│ │    │
│  │  │Task  │ │ (history)│ │ (note)   │ │      │ │Config│ │    │
│  │  └──────┘ └──────────┘ └──────────┘ └──────┘ └──────┘ │    │
│  └────────────────────────────────────────────────────────┘    │
│  ┌──────────────────┐  ┌─────────────────────────────┐         │
│  │  UserDefaults     │  │  Keychain (encryption keys) │         │
│  └──────────────────┘  └─────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────┘
         │                        │                     │
         ▼                        ▼                     ▼
   ┌───────────┐          ┌──────────────┐    ┌──────────────────┐
   │ APNs      │          │ Bark Server  │    │  Foundation      │
   │ (Apple)   │          │ (HTTP API)   │    │  Models (on-dev) │
   └───────────┘          └──────────────┘    └──────────────────┘
```

## 2. 技术栈

| 层级 | 技术 | 理由 |
|------|------|------|
| UI | SwiftUI | 声明式、现代、Widget / Live Activity 兼容 |
| 数据 | SwiftData | Apple 原生持久化，V2 iCloud 就绪 |
| 并发 | Swift Concurrency | async/await、actors、结构化并发 |
| 网络 | URLSession | 最小依赖，足以应对 Bark API |
| 加密 | CryptoKit + CryptoSwift | CryptoKit 现代加密，CryptoSwift 用于 Bark AES 兼容 |
| Markdown | swift-markdown | Apple 的 Markdown 解析器 |
| Live Activity | ActivityKit | iOS 16.1+；远程更新需 iOS 17+ |
| 设备端 LLM | FoundationModels framework | iOS 18+（Apple Intelligence 支持机型）|
| DI | Factory | 轻量 DI 容器（Phase 1 已用） |
| Keychain | KeychainSwift | 安全密钥存储 |
| 最低目标 | iOS 17.0 | 覆盖更广用户；iOS 18 特性（FoundationModels、ControlWidget、#Index）按版本自适应 |

### 依赖管理

使用 **Swift Package Manager (SPM)**。

```
Dependencies:
├── Factory (DI 容器)
├── KeychainSwift (安全存储)
├── CryptoSwift (Bark AES 兼容)
├── swift-markdown (Markdown 解析)
├── MarkdownView (Markdown 渲染)
└── ZIPFoundation (导出功能, P2)
```

> **注**：Apple Intelligence 设备端 LLM 通过系统 `FoundationModels` 框架接入，**不需要第三方依赖**，但需 iOS 18.1+ + 支持机型。

## 3. 模块架构

```
BarkMate/
├── App/                          # 主应用 target
│   ├── BarkAgentApp.swift
│   ├── Views/
│   │   ├── AgentDashboard/       # 主屏：Active agents 网格 + history timeline
│   │   ├── AgentDetail/          # 单 agent task 详情 + step 历史 + LLM 摘要
│   │   ├── MemoEditor/           # 备忘录编辑（次要功能）
│   │   ├── Server/               # 服务器管理
│   │   └── Settings/
│   └── ViewModels/
│
├── Packages/
│   ├── Models/                   # SwiftData 实体
│   │   ├── AgentTask.swift       # 持久 agent 卡片（核心新模型）
│   │   ├── AgentStep.swift       # task 的单次状态推送记录
│   │   ├── Memo.swift            # 用户备忘录（次要）
│   │   ├── Server.swift          # Bark 服务器
│   │   ├── Resource.swift        # 附件
│   │   └── CryptoConfig.swift    # 加密配置
│   │
│   ├── BarkService/              # Bark 协议接收
│   │   ├── BarkClient.swift      # 服务器注册 & API
│   │   ├── PushProcessor.swift   # 通知处理管线
│   │   ├── PushParser.swift      # 解析 Bark payload（含 v0.3 新字段）
│   │   ├── AgentRouter.swift     # 决定 payload 走 agent 路径还是 memo 路径
│   │   └── Processors/
│   │       ├── DecryptProcessor.swift
│   │       ├── ArchiveProcessor.swift     # AgentTask upsert / Memo insert
│   │       ├── LiveActivityProcessor.swift  # 触发 / 更新 / 闭合
│   │       ├── LevelProcessor.swift
│   │       ├── SoundProcessor.swift
│   │       ├── ImageProcessor.swift
│   │       └── IconProcessor.swift
│   │
│   ├── AgentKit/                 # 【新】Agent 状态机领域逻辑
│   │   ├── AgentTaskStore.swift  # AgentTask CRUD + 聚合逻辑
│   │   ├── StatusEngine.swift    # 状态转换 + stale 超时检测
│   │   └── SummaryEngine.swift   # 设备端 LLM 摘要封装（FoundationModels）
│   │
│   ├── Store/                    # 通用数据访问层
│   │   ├── MemoStore.swift
│   │   ├── ServerStore.swift
│   │   └── SearchEngine.swift
│   │
│   ├── MemoKit/                  # 备忘录编辑器组件（次要）
│   │   ├── MemoEditor.swift
│   │   ├── TagParser.swift
│   │   └── DraftManager.swift
│   │
│   ├── ActivityKit-Wrapper/      # 【新】Live Activity 抽象
│   │   ├── AgentActivity.swift   # ActivityAttributes 定义
│   │   ├── ActivityCoordinator.swift  # 主 app 侧创建/更新/结束
│   │   └── ActivityWidget.swift  # WidgetKit ActivityConfiguration
│   │
│   └── DesignSystem/             # 共享 UI 组件
│       ├── AgentCard.swift       # Dashboard 上半屏 agent 卡片
│       ├── StepRow.swift         # Agent 详情页的 step 行
│       ├── StatusBadge.swift     # 状态颜色徽章
│       ├── MemoCard.swift        # 备忘录卡片（history timeline）
│       ├── TagChip.swift
│       └── SearchBar.swift
│
├── NotificationServiceExtension/ # 推送处理（含 agent upsert）
├── ShareExtension/               # 共享内容 → memo
├── Widgets/                      # 主屏 / 锁屏 Widget（active agents）
├── LiveActivityExtension/        # 【新】Dynamic Island / 锁屏 Live Activity
└── AppIntents/                   # Siri Shortcuts
```

## 4. 数据模型

### 4.1 SwiftData Schema v2

V0.3 重写引入了 schema 升级：**从单一 `Item` 表拆分为 `AgentTask` + `AgentStep` + `Memo` 三表**，对应"agent 状态机"与"用户备忘录"的语义边界。

```swift
@Model
final class AgentTask {
    @Attribute(.unique) var id: UUID
    /// agent_id + task_id 的复合自然键，用于推送 upsert
    @Attribute(.unique) var aggregateKey: String   // "${agent_id}::${task_id}"
    var agentID: String                  // 来自推送 group / agent_id 字段
    var taskID: String?                  // 来自推送 task_id；nil 表示按 agent 聚合
    var displayName: String              // 展示用名称（首次推送的 title 或 agent_id）
    var iconURL: String?
    var status: AgentStatus              // .running / .waitingInput / .blocked / .done / .failed / .stale
    var latestStepTitle: String?         // 最新 step 的 title（卡片副标题）
    var progress: String?                // "3/7" 或 "45%" 或 nil
    var eta: Date?                       // 预计完成时间
    var isPinned: Bool
    var isArchived: Bool
    var isMuted: Bool
    var sourceServerID: UUID?
    var liveActivityID: String?          // 关联的 ActivityKit activity id
    var lastSummary: String?             // 缓存的 LLM 摘要（按需触发后写入）
    var lastSummaryAt: Date?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AgentStep.task)
    var steps: [AgentStep]
}

@Model
final class AgentStep {
    @Attribute(.unique) var id: UUID
    var task: AgentTask?
    /// 该 step 推送的状态快照
    var status: AgentStatus
    var title: String?
    var body: String
    var bodyType: BodyType               // .plainText / .markdown
    var progress: String?
    var url: String?
    var imageURL: String?
    var rawPayload: Data?                // JSON 编码的原始 Bark payload，调试用
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var resources: [Resource]
}

@Model
final class Memo {
    @Attribute(.unique) var id: UUID
    var title: String?
    var body: String
    var bodyType: BodyType               // 备忘录通常 .markdown
    var tags: [String]
    var isPinned: Bool
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var resources: [Resource]
}

@Model
final class Resource {
    @Attribute(.unique) var id: UUID
    var filename: String
    var mimeType: String
    var localPath: String
    var size: Int64
    var step: AgentStep?
    var memo: Memo?
}

@Model
final class Server {
    @Attribute(.unique) var id: UUID
    var name: String?
    var address: String                  // "https://api.day.app"
    var key: String                      // 设备注册 key
    var state: ServerState
    var lastSyncedAt: Date?
}

@Model
final class CryptoConfig {
    @Attribute(.unique) var id: UUID
    var serverID: UUID
    var algorithm: CryptoAlgorithm
    var mode: CryptoMode
    var keychainKeyRef: String           // 密钥存 Keychain
    var keychainIVRef: String?
    var isEnabled: Bool
    var createdAt: Date
}
```

### 4.2 枚举

```swift
enum AgentStatus: String, Codable {
    case running                          // agent 推送的 5 种状态 + 客户端推断的 stale
    case waitingInput  = "waiting_input"
    case blocked
    case done
    case failed
    case stale                            // 客户端推断：> N 分钟无更新且仍 running
}

enum BodyType: String, Codable {
    case plainText
    case markdown
}

enum ServerState: String, Codable { case ok, error }

enum CryptoAlgorithm: String, Codable { case aes128, aes192, aes256 }
enum CryptoMode: String, Codable { case cbc, ecb, gcm }
```

### 4.3 索引策略

```swift
// iOS 18+ 使用 #Index macro
@available(iOS 18.0, *)
extension AgentTask {
    static var indexes: [[PartialKeyPath<AgentTask>]] {
        [
            [\.aggregateKey],                    // upsert 主路径
            [\.isArchived, \.updatedAt],         // Dashboard 主查询（未归档 + 最近更新）
            [\.status, \.updatedAt],             // 状态过滤
            [\.isPinned, \.updatedAt],
        ]
    }
}

@available(iOS 18.0, *)
extension Memo {
    static var indexes: [[PartialKeyPath<Memo>]] {
        [
            [\.createdAt],
            [\.isArchived, \.createdAt],
        ]
    }
}

// iOS 17 回退：依靠 SQLite 自动创建的 PK/UK 索引
// `aggregateKey` 的 @Attribute(.unique) 在 iOS 17 也会生成唯一索引
```

> **注**：`AgentStep` 不建独立索引，通过 `AgentTask` 的关系查询访问；step 数量级远小于历史 Item 总量。

## 5. App Group 共享策略

主应用与 Extensions（NotificationServiceExtension、ShareExtension、Widgets、LiveActivityExtension）通过 App Group 共享数据。

### 5.1 共享边界

```
App Group: group.com.barkmate.shared
├── SwiftData Store (shared .sqlite)
│   └── 所有 target 共享同一个 ModelContainer
├── UserDefaults (suiteName: "group.com.barkmate.shared")
│   ├── 服务器配置缓存
│   ├── 通知偏好设置
│   ├── Widget 刷新标记
│   └── Stale 超时阈值（默认 30 分钟）
└── Shared File Container
    ├── pending_messages/    # NSE 写入，主应用消费
    ├── images/              # 推送图片
    └── resources/           # 备忘录附件
```

### 5.2 进程间协调

| 机制 | 用途 |
|------|------|
| Darwin Notification | NSE 写入新 AgentStep 后通知主应用刷新 Dashboard |
| UserDefaults KVO | Widget 监听 active agent 计数变化 |
| File Coordination | 主 app 和 NSE 同时写附件文件时的协调 |
| ActivityKit push token | NSE 拿到 push token 写共享存储，主 app 同步到服务器 |

### 5.3 SwiftData 多进程访问

复用 Phase 1 已验证方案：相同 `ModelContainer` 配置 + WAL 模式 + 短事务 + Darwin Notification。

## 6. NotificationServiceExtension 设计

V0.3 NSE 的核心变化：**根据 payload 是否包含 `agent_status` 字段决定路由——走 Agent 路径或走 Memo/Message 路径**。

### 6.1 资源限制（不变）

| 限制 | 值 | 应对策略 |
|------|-----|----------|
| 内存 | ~24MB（实际 50MB 会被 kill） | 轻量写入，不持有大对象 |
| 执行时间 | ~30 秒 | 各阶段超时降级 |
| 无 UI | 不能弹界面 | 静默完成 |

### 6.2 处理管线

```
APNs Payload
    │
    ▼
┌────────────────────────────────┐
│ 1. 解密 (DecryptStage)         │  CryptoSwift AES
├────────────────────────────────┤
│ 2. 解析 (ParseStage)           │  提取 Bark 标准字段 + v0.3 新字段
├────────────────────────────────┤
│ 3. 路由 (AgentRouter)          │  ① 有 agent_status → Agent 路径
│                                │  ② 无 agent_status → Message 路径（落 history）
├────────────────────────────────┤
│ 4a. Agent Upsert (ArchiveStage)│  按 aggregateKey upsert AgentTask + insert AgentStep
│ 4b. Message Archive            │  作为只读 step 落入 default agent 或 memo-like
├────────────────────────────────┤
│ 5. Live Activity (LAStage)     │  根据状态转换决定创建 / 更新 / 闭合
├────────────────────────────────┤
│ 6. 通知 (NotifyStage)          │  Darwin Notification → 主应用
├────────────────────────────────┤
│ 7. 富化 (EnrichStage)          │  图片下载、sound、level
├────────────────────────────────┤
│ 8. 呈现 (PresentStage)         │  返回 UNNotificationContent 给系统
└────────────────────────────────┘
```

### 6.3 Agent Upsert 关键逻辑

```swift
// 伪代码 — AgentTaskStore.upsert()
func upsert(payload: ParsedPayload, serverID: UUID) throws -> AgentTask {
    let agentID = payload.agentID ?? payload.group ?? "default"
    let taskID  = payload.taskID                       // 可能为 nil
    let key     = "\(agentID)::\(taskID ?? "_")"

    let existing = try context.fetch(
        FetchDescriptor<AgentTask>(predicate: #Predicate { $0.aggregateKey == key })
    ).first

    let task = existing ?? AgentTask(id: UUID(), aggregateKey: key, ...)
    task.status            = payload.agentStatus
    task.latestStepTitle   = payload.title
    task.progress          = payload.progress
    task.eta               = payload.eta
    task.updatedAt         = Date()

    let step = AgentStep(
        id: UUID(), task: task,
        status: payload.agentStatus,
        title: payload.title, body: payload.body,
        progress: payload.progress, ...
    )
    context.insert(step)
    try context.save()
    return task
}
```

### 6.4 Live Activity 触发规则（NSE 内）

| 入站状态 | LiveActivity 现状 | 动作 |
|----------|-------------------|------|
| running + eta 已知 | 不存在 | **创建** Live Activity，写 `liveActivityID` 到 AgentTask |
| running | 存在 | **更新** content state |
| waiting_input / blocked | 任意 | **更新** 至高亮状态（不关闭，仍在跑） |
| done / failed | 存在 | **结束** Live Activity（`dismissalPolicy: .immediate`），清空 ID |
| done / failed | 不存在 | 仅触发普通通知，不开 LA |

> **iOS 16.1 / 17 兼容**：LA 在 iOS 16.1 支持本地启动；远程 push 更新需 iOS 17.2+。NSE 无法直接启动 LA（需要主 app 在前台或后台运行才能 `Activity.request`），所以**远程启动必须依赖 server 端推送 `live-activity` push type**（S 阶段会扩展）。

### 6.5 降级（不变）

| 失败点 | 降级 |
|--------|------|
| 解密失败 | 存原始密文，标记 `encrypted` |
| 图片下载 | 存 URL，主 app 重试 |
| AgentTask 写入失败 | 进 pending queue，主 app 重放 |
| 不含 `agent_status` 的旧 Bark 推送 | 走 Message 路径，落入 history（不影响存量用户） |

## 7. 数据流

### 7.1 Agent 推送流

```
Agent / Hook → curl → Bark Server → APNs → iOS → NotificationServiceExtension
                                                  │
                                                  ├─ AgentRouter 判断路径
                                                  │
                                                  ├─→ AgentTaskStore.upsert()  (SwiftData)
                                                  │
                                                  ├─→ ActivityCoordinator (Live Activity)
                                                  │
                                                  ├─→ Darwin Notification → 主 app
                                                  │
                                                  └─→ System Notification
主 app 收到 Darwin Notification:
    │
    ├─→ Dashboard @Query 自动刷新（updatedAt DESC + isArchived == false）
    ├─→ Widget timeline 刷新
    └─→ pending queue 消费（图片重试等）
```

### 7.2 LLM 摘要流（按需触发）

```
用户点击 AgentCard → 进入 AgentDetail
    │
    └─→ 用户点击 "总结进度" 按钮（不自动触发）
          │
          ▼
        SummaryEngine.summarize(task:)
          ├─ 检查 lastSummary + lastSummaryAt（≤ 5 分钟则复用缓存）
          ├─ 检查 FoundationModels availability
          │   ├─ available → on-device LLM 推理
          │   └─ unavailable → 返回 .noModel（UI 改显示原始 step 列表）
          ├─ 组装 prompt：task.steps.title + body（最近 20 条）
          ├─ 调用 LanguageModelSession.respond(to:)
          └─ 结果写回 task.lastSummary / lastSummaryAt
```

**Prompt 模板**（V1）：
```
你是 agent 任务进度摘要助手。基于以下 step 历史，用 ≤3 句中文概括：
1) agent 现在在做什么；2) 进度如何；3) 是否有阻塞。

Steps:
[1] [10:23] running — 拉取依赖
[2] [10:25] running — 编译 src/...
...
```

**Privacy**：FoundationModels 完全 on-device，prompt 和 response 不出设备。Apple Intelligence 不可用时返回 `.noModel`，UI 降级为纯 step 列表。

### 7.3 备忘录流（不变）

```
用户 → MemoEditor → TagParser → DraftManager
                              → 保存
                                  ├─→ SwiftData (Memo)
                                  ├─→ Resource 文件写入
                                  └─→ Widget 刷新
```

### 7.4 搜索流

```
SearchEngine.search(query, scope)
    │
    ├─ scope == .all
    │   ├─→ AgentTask predicate (displayName / latestStepTitle CONTAINS)
    │   ├─→ AgentStep predicate (title / body CONTAINS)
    │   └─→ Memo predicate (title / body / tags CONTAINS)
    │
    └─ 按 updatedAt DESC 合并去重
```

## 8. Agent 状态机引擎

### 8.1 状态来源

客户端**完全信任 agent 推送的 `agent_status` 字段**，不强制状态机合法性（不校验 `done → running` 这类非法转换）。Agent 是事实来源。

### 8.2 Stale 超时

```swift
// StatusEngine.swift
actor StatusEngine {
    /// 主 app 启动 / Dashboard 出现 / 定时（5 分钟）触发
    func reconcileStale() async {
        let threshold = UserDefaults.shared.staleThresholdMinutes  // 默认 30
        let now = Date()
        let cutoff = now.addingTimeInterval(-TimeInterval(threshold * 60))

        let stuck = try? context.fetch(
            FetchDescriptor<AgentTask>(predicate: #Predicate {
                $0.status == .running && $0.updatedAt < cutoff
            })
        )
        stuck?.forEach { $0.status = .stale }
        try? context.save()
    }
}
```

驱动时机：
- 主 app 启动时一次
- Dashboard 出现时一次
- 后台 `BGAppRefreshTask` 注册周期任务（系统决定何时跑）
- 用户下拉刷新时一次

不在 NSE 里跑——NSE 资源紧张，且 stale 不需要实时。

### 8.3 状态颜色映射

| 状态 | 颜色 | 设计 token |
|------|------|-----------|
| running | 蓝 | `Color.accentBlue` |
| waiting_input | 黄 | `Color.warningYellow` |
| blocked | 橙 | `Color.alertOrange` |
| done | 绿 | `Color.successGreen` |
| failed | 红 | `Color.errorRed` |
| stale | 灰 | `Color.mutedGray` |

## 9. Live Activity 设计

### 9.1 ActivityAttributes

```swift
struct AgentActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
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

### 9.2 启动 / 更新 / 结束

| 操作 | 在哪里发生 | 备注 |
|------|-----------|------|
| 启动 | 主 app（前台或后台）/ 通过远程推送 `liveactivity` push type | NSE 自身不能 `Activity.request`，需要主 app 协助或 server 发 LA push |
| 更新 | NSE（每次推送进来） + 主 app（reconcile） | 通过 `Activity<...>.update(...)` |
| 结束 | NSE（终态推送）/ 主 app（用户归档） | `Activity.end(dismissalPolicy: .immediate)` |

### 9.3 远程更新 push token 流程

```
1. 主 app 启动 Activity → activity.pushTokenUpdates 异步流
2. 收到 token → 写 App Group UserDefaults + 上报 Bark server
3. Server 推送时若 task 有活跃 LA token → 同时发 LA push（push-type: liveactivity）
4. iOS 收到 LA push → 直接更新 Activity，不经过 NSE
```

## 10. 设备端 LLM 摘要

### 10.1 FoundationModels 集成

```swift
import FoundationModels

@available(iOS 18.1, *)
struct SummaryEngine {
    func summarize(task: AgentTask) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            throw SummaryError.unavailable
        }
        let session = LanguageModelSession(model: model)
        let prompt = buildPrompt(task: task)
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
```

### 10.2 触发与缓存策略

- **非自动触发**：用户进入 AgentDetail 后**手动点 "总结进度"** 才调用。理由：on-device 推理仍有功耗成本，避免后台滥用。
- **缓存**：`lastSummary` + `lastSummaryAt` 写回 AgentTask；若 task 在缓存有效期内（默认 5 分钟）无新 step，直接复用缓存。
- **可用性检查**：通过 `SystemLanguageModel.availability` 判断。不可用时（iOS 17、不支持机型、用户关闭 Apple Intelligence）UI 直接展示原始 step 列表，不显示"总结"按钮。

### 10.3 安全与隐私

- Prompt 和 response 全部 on-device。
- 不向 prompt 中拼接 server URL、key、Bearer token 等敏感字段（解析时显式 strip）。
- 输出渲染走与 Markdown 相同的沙箱（禁止 HTML）。

## 11. 搜索引擎

### 11.1 搜索范围

V0.3 搜索拆分为 3 个数据源：

```swift
struct SearchScope: OptionSet {
    let rawValue: Int
    static let agents = SearchScope(rawValue: 1 << 0)  // AgentTask
    static let steps  = SearchScope(rawValue: 1 << 1)  // AgentStep
    static let memos  = SearchScope(rawValue: 1 << 2)  // Memo
    static let all: SearchScope = [.agents, .steps, .memos]
}
```

### 11.2 实现

每个 scope 一个独立 `FetchDescriptor`，使用 `localizedStandardContains`。结果用 `SearchResult` 统一包装后按 `updatedAt` DESC 合并。

> 性能预期与 v0.2 一致：< 10k 条目下 < 200ms。超过 50k 走 V2 FTS5 升级路径。

## 12. 安全设计

### 12.1 威胁模型（更新）

| 威胁 | 风险 | V1 缓解 | V2 缓解 |
|------|------|---------|---------|
| 设备丢失，数据被提取 | 中 | iOS Data Protection (AFU) | SQLCipher + 生物识别 |
| Bark 推送内容中间人窃听 | 低（APNs TLS） | Bark E2E AES | — |
| 加密密钥泄露 | 中 | Keychain（硬件保护） | Secure Enclave 绑定 |
| LLM 摘要泄漏敏感字段 | **新** | strip server URL/key/auth header；on-device 推理；不上传 | — |
| 恶意 Bark server 注入伪造 agent_status | 中 | UI 信任 status 但展示来源 server；用户可静音/封禁 | server 签名 |
| Extension 内存 dump | 低 | 密钥用完释放 | — |

### 12.2 加密密钥管理（不变）

```
Keychain (kSecAttrAccessibleAfterFirstUnlock)
├── AES Key   → "barkmate.crypto.{serverID}.key"
├── AES IV    → "barkmate.crypto.{serverID}.iv"
└── access group → "{teamID}.com.barkmate.shared"
```

### 12.3 输入安全

- Markdown 渲染禁用 HTML 标签
- URL scheme 白名单：`http` / `https` / `tel` / `mailto`
- 图片下载仅 `https`，最大 10MB
- LLM prompt 构造时 strip 已知敏感字段

## 13. 错误处理策略

### 13.1 分层（基本沿用）

| 层级 | 策略 |
|------|------|
| Extension | 静默降级 |
| 数据层 | 重试 + pending queue |
| 网络层 | 指数退避 |
| LLM 层 | **新** — 可用性失败 → fallback 原始列表；推理失败 → 不缓存、UI 显示 "总结暂不可用" |
| UI 层 | 用户可见错误状态 |

### 13.2 Pending Queue（扩展任务类型）

```swift
enum PendingTaskType: String, Codable {
    case archiveStep
    case downloadImage
    case retryDecrypt
    case startLiveActivity     // NSE 无法直接启动 LA，落入队列由主 app 启动
    case endLiveActivity
}
```

## 14. Schema 迁移策略

### 14.1 V1 → V2 迁移

V0.3 重写涉及 schema 升级（Item → AgentTask + AgentStep + Memo）。Phase 1 已经创建了 `BarkAgentSchemaV1` 但内容是旧的 Item 设计，**需要先把 Phase 1 的 V1 schema 调整为本文档定义的形态**——因为 Phase 1 还没产生用户数据，可以直接覆盖而非迁移。

如果未来要支持从已发布版本的旧 schema 升级：

```swift
enum BarkAgentSchemaV1: VersionedSchema {
    static var models: [any PersistentModel.Type] = [
        AgentTask.self, AgentStep.self, Memo.self,
        Resource.self, Server.self, CryptoConfig.self
    ]
    static var versionIdentifier = Schema.Version(1, 0, 0)
}
```

### 14.2 迁移原则（不变）

- `metadata: Data?` 字段在各模型预留以支持 V2 扩展
- 优先 lightweight migration
- Extension 和主 app 必须使用相同 MigrationPlan
- 发版前必测迁移

## 15. 设计差异对比（v0.2 → v0.3）

| 维度 | v0.2 | v0.3 |
|------|------|------|
| 核心数据实体 | 单 `Item`（type 区分 push/memo） | `AgentTask` + `AgentStep` + `Memo` 三表 |
| 主屏 UI | 统一 timeline | 上半屏 Dashboard + 下半屏 history |
| 推送处理 | 解密 → 解析 → 归档 | 解密 → 解析 → **路由** → upsert / archive |
| Live Activity | 无 | 完整集成（NSE 触发 + remote push） |
| 设备端 LLM | 无 | FoundationModels 按需总结 |
| 备忘录优先级 | P0 | P1（次要功能） |
| 搜索范围 | 单一 Item | 三表联合搜索 |
| Schema | Item 中心 | 状态机中心 |
