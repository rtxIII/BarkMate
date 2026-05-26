# Phase 2 任务 2.0 — Schema 重构执行计划

> 版本: 0.2 | 日期: 2026-05-21 | 状态: **全部完成 ✅ (2.0.1–2.0.5);Models 11/11 + BarkService 63/63 + iOS Simulator build green)**
>
> 配合：`product.md` v0.3.0 / `design.md` v0.3.0 / `plan.md` v0.3.0

## 0. 背景

Phase 1 在 v0.2 设计下已经实现了**远超工作日志记载**的代码：

| 包 / Target | 已有 .swift 文件数 | 总 LoC（含测试） |
|------------|------------------|----------------|
| Models | 5 模型 + SchemaV1 | ~250 |
| BarkService | 12 source + 7 test | 1786 |
| Store | 6 source + 3 test | ~600 |
| DesignSystem | 6 组件 | ~? |
| App.Views | 8 视图 | ~? |
| ShareExtension | 2 文件 | ~? |
| NotificationServiceExtension | 1 文件 | ~? |

**18 个 .swift 文件直接引用 `Item`**——v0.3 改为 AgentTask + AgentStep + Memo 三表后，这 18 个文件全部需要触达。

⚠️ **关键约束**：没有用户数据需要迁移（应用未发布），所以 schema 可以**直接覆盖**，不需要 MigrationStage。

## 1. 关键决策（已确认）

### 1.1 旧协议（无 `agent_status` 字段）推送的归宿 — **方案 C**

旧 Bark 推送 → 作为 **incoming Memo**，与用户手写 memo 共享 `Memo` 表，通过 `source` 字段区分。

```swift
enum MemoSource: String, Codable {
    case manual              // 用户手写 / Share Extension
    case incoming            // 旧协议 Bark 推送（无 agent_status）
}
```

**理由**：
- 不引入第四张表（schema 复杂度可控）
- 旧协议推送本身就是"被动接收的信息"，语义与 memo 吻合
- 用户可以编辑、加标签、归档 incoming memo（统一管理）
- History timeline 渲染只看 Memo 表，不需要 union 两张表

### 1.2 aggregateKey 格式

`"<agentID>::<taskID-or-_>"`，`_` 表示 taskID 为 nil 的占位。SwiftData `@Attribute(.unique)` 强制唯一约束。

### 1.3 schema 直接覆盖

`BarkMateSchemaV1` 内容整体替换为新模型列表。**不**新建 `BarkMateSchemaV2` —— 因为没有用户数据，没必要保留 V1 历史。`MigrationPlan.stages` 仍为空数组。

## 2. 子任务依赖图

```
2.0.1 Models 重写  ──→  2.0.2 Store + DI  ──→  2.0.3 BarkService 改造
                                                       │
                          ┌────────────────────────────┘
                          ▼
                  2.0.4 DesignSystem 拆分  ──→  2.0.5 App.Views 替换
```

**串行执行**：每个子任务编译通过 + 测试通过后再进下一个。这样任何中间步骤翻车都能局部回滚。

## 3. 子任务 2.0.1 — Models 重写

### 3.1 目标

`Models` 包 schema 从单一 Item 表替换为 AgentTask + AgentStep + Memo 三表，外加 Resource / Server / CryptoConfig 不变。

### 3.2 文件变更

| 文件 | 操作 | 说明 |
|------|------|------|
| `Sources/Models/Item.swift` | **删除** | 替换为下面三个 |
| `Sources/Models/AgentTask.swift` | **新增** | design §4.1 定义 |
| `Sources/Models/AgentStep.swift` | **新增** | design §4.1 定义 |
| `Sources/Models/Memo.swift` | **新增** | design §4.1 定义 + `source: MemoSource` 字段 |
| `Sources/Models/Enums.swift` | **改写** | 删 `ItemType`；增 `AgentStatus`、`MemoSource`；保留 `BodyType`、`ServerState`、`CryptoAlgorithm`、`CryptoMode` |
| `Sources/Models/Resource.swift` | **改写** | `item: Item?` → `step: AgentStep?` + `memo: Memo?`（二选一） |
| `Sources/Models/Server.swift` | 不动 | |
| `Sources/Models/CryptoConfig.swift` | 不动 | |
| `Sources/Models/SchemaV1.swift` | **改写** | `models` 数组替换为 `[AgentTask, AgentStep, Memo, Resource, Server, CryptoConfig]` |
| `Tests/ModelsTests/ModelsTests.swift` | **重写** | 删 Item 相关测试，新增 AgentTask upsert / AgentStep cascade / Memo source 测试 |

### 3.3 关键代码骨架

```swift
// AgentTask.swift
@Model
public final class AgentTask {
    #Index<AgentTask>(
        [\.aggregateKey],
        [\.isArchived, \.updatedAt],
        [\.statusRaw, \.updatedAt],
        [\.isPinned, \.updatedAt]
    )

    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var aggregateKey: String
    public var agentID: String
    public var taskID: String?
    public var displayName: String
    public var iconURL: String?
    public var statusRaw: String
    public var latestStepTitle: String?
    public var progress: String?
    public var eta: Date?
    public var isPinned: Bool
    public var isArchived: Bool
    public var isMuted: Bool
    public var sourceServerID: UUID?
    public var liveActivityID: String?
    public var lastSummary: String?
    public var lastSummaryAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AgentStep.task)
    public var steps: [AgentStep]

    public init(...) { ... }
}

extension AgentTask {
    public var status: AgentStatus {
        get { AgentStatus(rawValue: statusRaw) ?? .running }
        set { statusRaw = newValue.rawValue }
    }

    public static func aggregateKey(agentID: String, taskID: String?) -> String {
        "\(agentID)::\(taskID ?? "_")"
    }
}
```

```swift
// Memo.swift
@Model
public final class Memo {
    #Index<Memo>(
        [\.createdAt],
        [\.isArchived, \.createdAt],
        [\.sourceRaw, \.createdAt]
    )

    @Attribute(.unique) public var id: UUID
    public var sourceRaw: String      // MemoSource.rawValue
    public var title: String?
    public var body: String
    public var bodyTypeRaw: String
    public var tags: [String]
    public var group: String?         // 旧协议 incoming memo 的 Bark group 字段
    public var sourceServerID: UUID?  // incoming memo 来源
    public var url: String?
    public var imageURL: String?
    public var isPinned: Bool
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Resource.memo)
    public var resources: [Resource]

    public init(...) { ... }
}
```

### 3.4 完成标准

- [ ] `swift build` 编译通过（在 Models 包内）
- [ ] `swift test --filter ModelsTests` 全绿
- [ ] `BarkMateSchemaV1.models` 包含 6 个类型
- [ ] AgentTask `aggregateKey` 唯一约束生效（测试：重复插入抛错）
- [ ] AgentTask 删除 → cascade 删除其 AgentStep（测试覆盖）
- [ ] Memo `source` 字段可读写（测试 manual / incoming 都能存）

### 3.5 风险

- **`#Index` 的字段引用**：必须用 `statusRaw`（String）而不是 `status`（computed AgentStatus），否则 SwiftData macro 报错
- **Resource 双向反向关系**：`step: AgentStep?` + `memo: Memo?` 二选一，需要在 AgentStep 和 Memo 中分别声明 inverse，避免 SwiftData 推断错误

### 3.6 估时

约 2-3 小时（代码 ~200 行 + 测试 ~150 行）

---

## 4. 子任务 2.0.2 — Store + DI 调整

### 4.1 目标

`Store` 包的 schema 引用 / Darwin Notification payload 适配新模型。

### 4.2 文件变更

| 文件 | 操作 | 说明 |
|------|------|------|
| `Sources/Store/SharedModelContainer.swift` | **小改** | 引用更新（如果之前显式列了 Item.self） |
| `Sources/Store/DarwinNotification.swift` | **可能小改** | 如果 payload 里有 Item.id 改为通用 "refresh" 通知 |
| `Sources/Store/DeviceTokenStore.swift` | 不动 | |
| `Sources/Store/DraftManager.swift` | 不动 | 草稿是字符串，与模型无关 |
| `Sources/Store/KeychainService.swift` | 不动 | |
| `Sources/Store/AppGroup.swift` | 不动 | |
| `Tests/StoreTests/SharedModelContainerTests.swift` | **改写** | 测试 fixture 改为 AgentTask / Memo |
| `Tests/StoreTests/KeychainServiceTests.swift` | 不动 | |
| `Tests/StoreTests/DraftManagerTests.swift` | 不动 | |
| `App/Sources/DI/Container+App.swift` | 验证 | sharedModelContainer 注入不变 |
| `NSE/Sources/DI/Container+Extension.swift` | 验证 | 同上 |

### 4.3 完成标准

- [ ] `swift build` 整个 workspace 编译通过到 Store 包
- [ ] `swift test --filter StoreTests` 全绿
- [ ] 跨进程共享测试用 AgentTask 替代 Item，验证两个 ModelContainer 看到同一条记录

### 4.4 估时

约 1 小时

---

## 5. 子任务 2.0.3 — BarkService 改造（最大） ✅ **(2026-05-20 完成)**

### 5.1 目标

PushParser 扩展 v0.3 字段；新增 AgentRouter 决定路由；新增 AgentTaskStore 做 upsert；PushArchiver 拆分；SearchEngine 改为三表联合。

### 5.2 文件变更

| 文件 | 操作 | 说明 |
|------|------|------|
| `Sources/BarkService/PushParser.swift` | **扩展** | `ParsedPush` 增加 `agentStatus: AgentStatus?` / `taskID: String?` / `progress: String?` / `eta: Date?`；parse 函数提取这 4 个字段 |
| `Sources/BarkService/AgentRouter.swift` | **新增** | `enum RoutingDecision { case agent(ParsedPush), memo(ParsedPush) }`；`func route(ParsedPush) -> RoutingDecision`（依据 `agentStatus != nil`） |
| `Sources/BarkService/AgentTaskStore.swift` | **新增** | `upsert(parsed: ParsedPush) throws -> AgentTask`；按 aggregateKey 查找；查到则 update + insert step；查不到则 create |
| `Sources/BarkService/PushArchiver.swift` | **改写** | 重命名为 `MemoArchiver` 或保留但改成 dispatch：内部根据 AgentRouter 决定调用 AgentTaskStore.upsert 还是 MemoArchiver.archive(source: .incoming) |
| `Sources/BarkService/SearchEngine.swift` | **改写** | `SearchScope` enum；三个 filter 函数（agents/steps/memos）；`SearchResult` 统一包装类型 |
| `Sources/BarkService/DecryptProcessor.swift` | 不动 | |
| `Sources/BarkService/ImageEnricher.swift` | **小改** | 入参从 Item 改为 AgentStep 或 Memo |
| `Sources/BarkService/PendingQueue.swift` | **小改** | task type 增加 `startLiveActivity` / `endLiveActivity`（Phase 5 才用，但定义先加） |
| `Sources/BarkService/CryptoBundle.swift` | 不动 | |
| `Sources/BarkService/CryptoSettingsStore.swift` | 不动 | |
| `Sources/BarkService/BarkClient.swift` | 不动 | |
| `Tests/BarkServiceTests/PushParserTests.swift` | **扩展** | 增加 v0.3 字段解析测试（含 agent_status 各枚举值、eta ISO8601 解析） |
| `Tests/BarkServiceTests/PushArchiverTests.swift` | **重写** | 拆为 AgentTaskStoreTests + MemoArchiverTests |
| `Tests/BarkServiceTests/SearchEngineTests.swift` | **重写** | 三表联合 + scope 切换 |
| `Tests/BarkServiceTests/AgentRouterTests.swift` | **新增** | 路由决策测试（有/无 agent_status / 错误枚举值） |
| `Tests/BarkServiceTests/DecryptProcessorTests.swift` | 不动 | |
| `Tests/BarkServiceTests/ImageEnricherTests.swift` | **小改** | fixture 适配 |
| `Tests/BarkServiceTests/PendingQueueTests.swift` | **小改** | 验证新 task type 可编解码 |
| `Tests/BarkServiceTests/BarkClientTests.swift` | 不动 | |

### 5.3 关键代码骨架

```swift
// PushParser.swift — ParsedPush 扩展
public struct ParsedPush: Sendable, Equatable, Codable {
    // ... 原有字段保留 ...
    public let agentStatus: AgentStatus?  // 新增
    public let agentTaskID: String?       // 新增 (映射 payload.task_id)
    public let progress: String?          // 新增
    public let eta: Date?                 // 新增
}

// AgentRouter.swift
public enum RoutingDecision: Equatable {
    case agent(ParsedPush)
    case incomingMemo(ParsedPush)
}

public enum AgentRouter {
    public static func route(_ parsed: ParsedPush) -> RoutingDecision {
        parsed.agentStatus == nil ? .incomingMemo(parsed) : .agent(parsed)
    }
}

// AgentTaskStore.swift
public struct AgentTaskStore {
    private let modelContainer: ModelContainer
    public init(modelContainer: ModelContainer) { ... }

    @discardableResult
    public func upsert(parsed: ParsedPush) throws -> UUID {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        let agentID = parsed.group ?? "_default"  // group → agentID
        let key = AgentTask.aggregateKey(agentID: agentID, taskID: parsed.agentTaskID)

        let existing = try context.fetch(
            FetchDescriptor<AgentTask>(predicate: #Predicate { $0.aggregateKey == key })
        ).first

        let task = existing ?? AgentTask(
            id: UUID(), aggregateKey: key, agentID: agentID, taskID: parsed.agentTaskID,
            displayName: parsed.title ?? agentID, ...
        )
        if existing == nil { context.insert(task) }

        task.status = parsed.agentStatus ?? .running
        task.latestStepTitle = parsed.title
        task.progress = parsed.progress
        task.eta = parsed.eta
        task.updatedAt = parsed.createdAt

        let step = AgentStep(
            id: deterministicUUID(from: parsed.id),
            task: task, status: task.status,
            title: parsed.title, body: parsed.body,
            ...
        )
        context.insert(step)
        try context.save()
        return task.id
    }
}
```

### 5.4 完成标准

- [x] `swift build` 编译通过到 BarkService
- [x] `swift test --filter BarkServiceTests` 全绿（**63/63 通过 @ 2026-05-20**）
- [x] AgentRouter：有 agent_status 走 agent 路径；无走 memo 路径（AgentRouterTests x8）
- [x] AgentTaskStore.upsert：同 aggregateKey 两次推送 → 1 AgentTask + 2 AgentStep（PushArchiverTests，upsert 实际写在 `PushArchiver.upsertAgentTask` 私有方法，暂未抽独立 store）
- [x] Schema 三表联合搜索：query "foo" 能同时命中 AgentTask.displayName / AgentStep.title / Memo.body（SearchEngineTests x21）
- [x] PushParser 解析含 v0.3 字段的 payload，4 个新字段全部正确（PushParserTests）

### 5.4-bis 与原设计的偏差

- **PushArchiver 没拆为 AgentArchiver + MemoArchiver 两个文件**：保留单文件 + 内部 switch 派发到 `upsertAgentTask` / `archiveMemo` 私有方法。NSE 调用方只需 `archive(_:)` 一次。
- **AgentTaskStore 暂未抽出独立类型**：upsert 逻辑直接写在 `PushArchiver.upsertAgentTask`，等 Phase 3 主 App 出现 pin/mute/archive 等 CRUD 需求时再抽。
- **SearchEngine 用 OptionSet `SearchScope`（沿用 design §11.1）**，而非 plan §5.3 骨架里草拟的 enum，支持 `[.agents, .memos]` 组合。
- **SearchEngine 是内存过滤而非 SwiftData `#Predicate`**：因为 `localizedStandardContains` 在 `#Predicate` 不支持（中文 / 大小写不敏感），改为 `context.fetch` 全表后内存过滤。10k 量级足够，超 50k 走 V2 FTS5。
- **`SearchResult` 不实现 `Sendable`**：底层是 `@Model` 引用类型，仅在所属 ModelContext 线程内有效，不跨线程；`Equatable` 基于 `id` 比较。

### 5.5 风险

- **AgentTaskStore.upsert 的竞态**：同 aggregateKey 短时间内 2 次推送 → 两个 ModelContext 都查 not exist → 都 insert → unique 约束抛错。**缓解**：用 `do-try-catch` 包裹 save，catch unique 违反时重新 fetch 再 update（一次重试）
- **AgentStep id 重复**：APNs 可能重推同一条，需要 `deterministicUUID(from: parsed.id)` 保证幂等
- **SearchEngine 内存占用**：三表联合 fetch 在 50k 条目下可能撑爆，需要分页（V1 接受 limit=200 截断）

### 5.6 估时

约 6-8 小时（含测试），是 5 个子任务里最大块

---

## 6. 子任务 2.0.4 — DesignSystem 拆分 ✅ **(2026-05-21)**

### 6.1 目标

ItemCard 拆为 AgentCard + MemoCard；新增 StatusBadge / StepRow。

### 6.2 文件变更

| 文件 | 操作 | 说明 |
|------|------|------|
| `Sources/DesignSystem/ItemCard.swift` | **删除** | 拆分 |
| `Sources/DesignSystem/AgentCard.swift` | **新增** | AgentTask → 卡片视图 |
| `Sources/DesignSystem/MemoCard.swift` | **新增** | Memo → 卡片视图 |
| `Sources/DesignSystem/StepRow.swift` | **新增** | AgentStep → 详情页单行 |
| `Sources/DesignSystem/StatusBadge.swift` | **新增** | AgentStatus → 颜色徽章 |
| `Sources/DesignSystem/Theme.swift` | **扩展** | 加状态色 token：accentBlue / warningYellow / alertOrange / successGreen / errorRed / mutedGray |
| `Sources/DesignSystem/TagChip.swift` | 不动 | |
| `Sources/DesignSystem/HighlightedText.swift` | 不动 | |
| `Sources/DesignSystem/MarkdownBodyView.swift` | 不动 | |

### 6.3 完成标准

- [ ] AgentCard / MemoCard / StepRow / StatusBadge SwiftUI Preview 都能正常渲染
- [ ] StatusBadge 6 种状态颜色与 design §8.3 一致
- [ ] 无 Models.Item 引用残留

### 6.4 估时

约 2-3 小时（含 Preview）

---

## 7. 子任务 2.0.5 — App.Views 替换 ✅ **(2026-05-21)**

> 实际执行偏差:相比原计划只做 schema 字段切换,本次顺带完成了 plan.md §3.0 视觉对齐(5 tab + DesignSystem 21 组件 + Iowan typography token + paperHot 卡 + 深色 hero)。`ItemTimelineView` 已删除并拆为 `AgentDashboardView` + `HistoryView` + `AgentDetailView`,`AgentMockPrototypeView` 加文件头禁修契约注释。`LegacyItem.swift` 已删除,`PushArchiver.archive(_:type:)` 签名改为 `archive(_:fallbackMemoSource:)`。

### 7.1 目标

主视图层切换到新模型。**这是用户能看到效果的一步**。

### 7.2 文件变更

| 文件 | 操作 | 说明 |
|------|------|------|
| `App/Views/ItemTimelineView.swift` | **改名 + 重写** → `AgentDashboardView.swift` | 上半屏 active agents 网格 + 下半屏 history（已归档 agent + Memo） |
| `App/Views/AgentDetailView.swift` | **新增** | AgentTask 详情：当前状态 + 进度 + step 历史 + "总结进度" 按钮（占位） |
| `App/Views/MemoEditorView.swift` | **改写** | 使用 Memo 模型，`source: .manual` |
| `App/Views/SearchView.swift` | **改写** | 接入新 SearchEngine + scope chips |
| `App/Views/MainTabView.swift` | **小改** | TimelineView → AgentDashboardView |
| `App/Views/ContentView.swift` | 视情况 | 如果只是 root，几乎不动 |
| `App/Views/SettingsView.swift` | **扩展** | 加"Stale 超时阈值"配置项；"Apple Intelligence 总结" 开关占位 |
| `App/Views/ServerListView.swift` | 不动 | |
| `App/Views/AddServerView.swift` | 不动 | |
| `ShareExtension/Sources/ShareViewController.swift` | **改写** | `Item(type: .memo)` → `Memo(source: .manual)` |
| `ShareExtension/Sources/ShareView.swift` | 视情况 | 如果只显示 toast，可能不动 |
| `App/Sources/PendingQueueDrainer.swift` | **小改** | 处理新 task type |
| `Widgets/Sources/BarkMateWidgets.swift` | 验证 | 仍是占位则不动；如果已查询 Item 则改 AgentTask |
| `NSE/Sources/NotificationService.swift` | **小改** | 装配 AgentRouter + AgentTaskStore + MemoArchiver |

### 7.3 完成标准

- [ ] App 整体 build 通过
- [ ] Simulator 启动后 Dashboard 显示空状态引导
- [ ] 模拟推送（含 agent_status）→ Dashboard 出现卡片
- [ ] 模拟推送（无 agent_status）→ History timeline 出现 incoming memo
- [ ] 写一条手写 memo → History timeline 出现 manual memo
- [ ] Share 一条链接 → History 出现 manual memo

### 7.4 估时

约 4-6 小时

---

## 8. 总估时与节奏

| 子任务 | 估时 | 累计 |
|--------|------|------|
| 2.0.1 Models | 2-3h | 3h |
| 2.0.2 Store + DI | 1h | 4h |
| 2.0.3 BarkService | 6-8h | 12h |
| 2.0.4 DesignSystem | 2-3h | 15h |
| 2.0.5 App.Views | 4-6h | 21h |
| **合计** | **15-21h** | |

**节奏建议**：
- 一天专注做完 2.0.1 + 2.0.2（编译跑通绿）
- 一天专注做 2.0.3（最复杂，含测试）
- 一天专注 2.0.4 + 2.0.5（视觉收尾 + Simulator 验证）

3 个工作日内可以全部跑完。

## 9. 回滚策略

- 每个子任务一个 git commit（甚至一个 PR）
- 子任务 2.0.3 内部如果中途翻车，可以 revert 单 commit 退回到 2.0.2 状态
- **不在 2.0.5 全部做完前合 main**，因为中间状态主 app 不可启动

## 10. 与 Server S4 的协同

Server S4 conformance 测试（0.5h）可以与 2.0.1 并行，不影响 iOS。

S4 Live Activity 端点（~4h）属于 V1.1 范围，不阻塞 V1.0，可以推到 Phase 5 启动前再做。

## 11. 老板需 review 的关键点

1. **MemoSource 字段设计**（§1.1）：incoming memo 用同一张表是否 OK？或者你更想要独立 Message 表？
2. **aggregateKey 用 `_default` 作为缺省 agentID**（§5.3）：还是改用 `"<server-id-prefix>::_"` 之类区分 server？
3. **AgentStep id 用 deterministic UUID**（§5.5）：和 v0.2 PushArchiver 的去重策略一致，但 step 没有"覆盖"语义只有"插入"，重复推送应该被丢弃 → 这个去重逻辑要写在 upsert 里
4. **estimate 21h 是否符合你的节奏预期？** 太长可以砍 2.0.4（视觉延后）或简化测试覆盖
5. **每个子任务的 commit 粒度**：1 commit/子任务 还是更细？
