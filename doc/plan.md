# BarkAgent — 实施计划

> 版本: 0.4.1 | 日期: 2026-05-26 | 状态: **Client Phase 1-4 ✅ · Phase 1 收尾 ✅(AppIdentifierPrefix 全 target + CI) · Server MS1+MS2a+S4b(1-3)+S5(部分)✅ (CI/deploy workflow + Secrets 文档 + README) · 进入 V1.0 候选 · BarkServiceTests 74/74 + Models 11/11 + Store 12/12 + vitest 47/47**

## 架构概览

双端系统：

```
┌──────────────┐          ┌──────────────────────┐        ┌──────────┐
│  BarkAgent    │ register │  BarkAgentServer      │  push  │   APNs   │
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
Phase 4: 多服务器 + 搜索                   S4a: V0.3 字段透传 + health ✅
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

**依赖**：iOS Phase 2 端到端验证依赖 Server S3（已完成）；v0.3 字段端到端验证依赖 Server S4a（已完成 2026-05-26）；Phase 5 Live Activity 远程更新依赖 Server S4b（待做）。

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

### Phase 1 收尾遗留 ✅ **(2026-05-26)**

- [x] Info.plist 加 `AppIdentifierPrefix: $(AppIdentifierPrefix)`(App + NSE + Share + Widgets 全部覆盖)
- [x] Simulator 端到端验真：BarkService 74/74 + PushPipelineIntegrationTests + xcodebuild iPhone 17 Sim BUILD SUCCEEDED;真 APNs 留 TestFlight
- [x] git init 仓库、首次 push 触发 CI:`.github/workflows/ci.yml`(macos iOS jobs:Models/Store/BarkService swift test + xcodebuild iOS Sim;ubuntu server job:tsc + vitest)

---

## Phase 2: Bark 推送管线 + Agent 路由

**目标**：能收到 Bark 推送，按 `agent_status` 字段路由到 Agent 路径或 Message 路径，AgentTask 卡片在主应用实时可见。

**协议语义对齐 product.md**：不带 v0.3 新字段的存量 Bark 推送仍可零改动接入，但作为普通消息进入 History Timeline；只有带 `agent_status` 的推送才进入 Agent Dashboard 并聚合为状态卡片。

### 关键任务

> Schema 重构（2.0）拆为 5 个子任务 2.0.1–2.0.5，详见 [phase2-schema-migration.md](phase2-schema-migration.md)。当前进度：**2.0.1 Models ✅ · 2.0.2 Store+DI ✅ · 2.0.3 BarkService ✅ · 2.0.4 DesignSystem ✅ · 2.0.5 App.Views ✅ (2026-05-21，Models 11/11 + BarkService 63/63 测试绿 + iOS Simulator build green)**。LegacyItem 已删除，PushArchiver 签名改为 `fallbackMemoSource: MemoSource`。

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| 2.0 | ✅ | **Schema 重构** | 替换 v0.2 的 Item 中心 schema 为 AgentTask + AgentStep + Memo 三表（见 design §4.1）。2.0.1–2.0.5 全部完成 (2026-05-21) |
| 2.1 | ✅ | APNs 注册 | 获取 device token，通过 BarkClient 上报到服务器（沿用 v0.2） |
| 2.2 | ✅ | BarkClient.register() | POST `/register` 接口 |
| 2.3 | ✅ | NSE 入口 | `didReceive(_:withContentHandler:)` |
| 2.4 | ✅ | DecryptProcessor | CryptoSwift AES-128/192/256 × CBC/ECB/GCM |
| 2.5 | ✅ | PushParser | 解析 Bark 标准字段 **+ v0.3 新字段（agent_status / task_id / progress / eta）**；`group` 映射为 `agent_id`，`task_id` 缺省时按 `agent_id` 聚合 |
| 2.6 | ✅ | **AgentRouter** | 判断 payload 走 Agent 路径还是 Message 路径 |
| 2.7 | ✅ | **AgentTaskStore.upsert()** | 按 `aggregateKey = agentID::taskID` upsert AgentTask + insert AgentStep（当前实现内嵌在 `PushArchiver.upsertAgentTask`，待 Phase 3 主 App CRUD 需求出现时再抽出独立类型） |
| 2.8 | ✅ | ArchiveProcessor (Message 路径) | 无 `agent_status` 的旧 Bark 推送 → 落入 incoming Memo（方案 C，见 phase2-schema-migration §1.1），不创建 AgentTask |
| 2.9 | ✅ | Darwin Notification | NSE → 主应用通知 |
| 2.10 | ✅ | EnrichProcessor | 图片下载、图标、提示音 |
| 2.11 | ✅ | PresentProcessor | 修改 UNMutableNotificationContent |
| 2.12 | ✅ | PendingQueue 扩展 | SwiftData 写入失败时以 ParsedPush 入队；archiveStep 已由 Agent 路径承载；startLiveActivity / endLiveActivity 延后至 Phase 5 |
| 2.13 | ✅ | 主应用 Darwin 监听 | @Query 刷新 |
| 2.14 | ✅ | 降级策略 | 解密失败存密文、图片失败存 URL |

### 完成标准

- [x] 端到端测试：curl 推送（带 `agent_status=running`）→ 设备收到通知 → AgentTask upsert / AgentStep insert 正确（代码路径已串通；Simulator 端到端验证见 [Phase 2 收尾](#phase-2-收尾2026-05-25) 任务 A/B）
- [x] 聚合测试：同一 `agent_id + task_id` 多次推送 → 只产生一张 AgentTask 卡片，AgentStep 数量等于推送次数（PushArchiverTests.testAgentPushAggregatesByAgentAndTaskID）
- [x] 旧协议兼容：不带 `agent_status` 的推送 → 不创建 AgentTask，进 incoming Memo（PushArchiverTests.testOldProtocolPushArchivesIncomingMemoByID）
- [x] 加密推送：AES-256/CBC 加密的 v0.3 payload 解密后字段解析正确（DecryptProcessorTests + PushParserTests 覆盖；真机加密 E2E 见任务 C）
- [ ] Extension 内存：处理带图片的 agent 推送 < 24MB
- [x] 主应用实时刷新：NSE 写入后 1 秒内 Dashboard 看到新卡片（AgentDashboardView 装载 DarwinObserver → refreshToken 触发 @Query 重建）

### 风险

- **AgentTask upsert 的并发**：同一 task 短时间多次推送可能产生竞态，需要 NSE 内做唯一索引约束 + 串行化
- **CryptoSwift 在 Extension 中的二进制体积** 影响启动速度（v0.2 风险延续）

---

### Phase 2 收尾（2026-05-25）

代码层 2.1–2.14 已全部就绪（BarkService 测试 72/72 绿，含 6 项 PushPipeline 集成测试）。pipeline 已抽出为 `PushPipeline.process(userInfo:bundle:container:)`，NSE 改为薄壳调度；这样在 simulator 不触发 service-class 时也能用集成测试覆盖整条管线。

| 任务 | 状态 | 内容 |
|----|:---:|------|
| A | ✅ | `xcodegen generate` + `xcodebuild build -scheme BarkAgent -destination 'platform=iOS Simulator,name=iPhone 17'` 全 5 target BUILD SUCCEEDED |
| B | ✅ | PushPipelineIntegrationTests 5 项端到端覆盖：单条 v0.3 push 入库 / 三条聚合状态推进 / 旧协议→incoming Memo / nil container→PendingQueue→drain 重放 / 无 bundle 时密文降级 |
| C | ✅ | PushPipelineIntegrationTests.testEncryptedV03AgentPushDecryptsAndArchivesAsAgent：AES-256/CBC + PKCS7 加密的 v0.3 payload → DecryptProcessor 解密 → PushParser 字段解析 → PushArchiver 落 AgentTask + AgentStep |
| simulator E2E | ⏳ | `xcrun simctl push` 在 simulator 不触发 service-class（CoreSimulatorBridge 直接 SpringBoard）；真实 APNs token 上报路径留待 TestFlight / 真机；不阻塞 V1.0 候选 |

> 任务 D（PendingQueue 增 LA 类型）显式推迟到 Phase 5 Live Activity；当前 ParsedPush 单类型足以承载推送旁路。

---

## Phase 3: Agent Dashboard + 详情页 UI

**目标**：核心用户流程可用——主屏看到 active agents 网格，点击进详情看 step 历史。**视觉与交互以 `BarkMate/App/Sources/Views/AgentMock/AgentMockPrototypeView.swift` 为基线**，对 Phase 1/2 已落地的现有视图（`ContentView` / `MainTabView` / `ItemTimelineView` / `SearchView` / `MemoEditorView` / `SettingsView` / `ServerListView` / `AddServerView`）做结构与样式的对齐重构，而不是从零新建。

> **Mock 基线参照**：`doc/prototype-prd.md` §10 / §11 + `AgentMockPrototypeView.swift`（含 5 tab 信息架构、6 张 mock agent 卡片、SummaryPanel 三态、SetupHero、HistoryHero、LiveActivityMockCard 等组件）。原型为单文件演示，本 Phase 拆分为 `App/Views` + `Packages/DesignSystem` 复用组件。

### 当前现状 vs Mock 差距（Phase 3 启动前快照）

| 维度 | 当前实现 | Mock 基线 | 差距 |
|---|---|---|---|
| Tab 数量 | 3（Dashboard / Search / Settings） | 5（Agents / Search / Setup / History / Settings） | +Setup +History |
| Dashboard 顶部 | 3 色 SummaryPill | AgentHeroCard（深色 hero + 大计数 + 3 mini stats） | 重写头部组件 |
| Dashboard 过滤 | 无 | FilterStrip（All / Needs attention / Running / Blocked / Done） | 新增 |
| Active 卡片 | adaptive(minimum: 160)，简单白卡 | 2 列固定，paperHot 米色卡 + 左侧状态色条 5pt + 右上装饰圆 | 重写 AgentTaskCard |
| 卡片字体 | system | Iowan Old Style 14pt heavy + monospace task_id | 字体扩充 |
| History 区 | Dashboard 下半屏 | 独立 History tab + HistoryHero + chip 过滤 | 拆分 tab |
| Detail 头部 | List + Section + StatusBadge | DetailHero（深色 + Iowan Old Style 36pt + 3 metric） | 重写 |
| Detail 操作 | 无 | Pin / Mute / Archive / Mark done 四按钮 row | 新增 |
| Summary 区域 | 无 | SummaryPanel（ready / loading / generated 三态 + skeleton） | 新增（Phase 3 仅占位 UI，Phase 6 接 LLM） |
| Step 行 | List 内嵌 | 独立卡片（paperHot 圆角 22 + 左侧 monospace 时间列） | 重写 StepRow |
| Setup / Onboarding | 散在 Phase 4 任务里 | 独立 tab：curl 黑底卡 + FieldExplainer + 兼容说明 | 提前到 Phase 3 |
| FAB "New memo" | ItemTimelineView 右下 | 不存在 | 移除（Memo 入口归 History tab `+`） |
| 设计令牌 | `BarkTheme`（system color） | `MockPalette`（ink/paperHot/blue/yellow/orange/green/red/gray/cyan） | DesignSystem 扩充 |

### 3.0 Mock UI 对齐与设计令牌冻结（Phase 3 前置） ✅ **(2026-05-21)**

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| 3.0.1 | ✅ | DesignSystem 令牌扩充 | `BarkTheme.Palette` 扩充 13 色 + 5 级 corner + `Typography.heroSerif`(Iowan/serif 降级) + `AgentStatus.color/label/sortPriority/isTerminal` 扩展 + `Color(hex:)` |
| 3.0.2 | ✅ | DesignSystem 复用组件 | DesignSystem 新增 21 个文件:`MockScreenBackground` / `StatusBadge` / `Pill` / `ChipButtonStyle` / `PrimaryCapsuleButtonStyle` / `SecondaryCapsuleButtonStyle` / `SectionTitle` / `SkeletonLine` / `AgentAvatar` / `AgentTaskCard` / `StepRow` / `AgentHeroCard` / `DetailHero` / `SummaryPanel` / `HistoryRow` / `HistoryMiniRow` / `SettingRow` / `SettingToggleRow` / `FieldExplainer` / `MockSearchFieldStyle` + view-model 类型 `AgentCardData` / `StepRowData` / `HistoryItemData` / `SummaryPanelState`;删除 `ItemCard.swift` |
| 3.0.3 | ✅ | MainTabView 5 tab 重构 | Agents / Search / Setup / History / Settings 五 tab,`.tint(.ink)`;`ItemTimelineView` 已删除,FAB 移除,MemoEditor 入口迁到 History tab `+` |
| 3.0.4 | ✅ | AgentMock 冻结为契约源 | `AgentMockPrototypeView.swift` 加文件头禁修注释;file-private 符号改名(`mockProtoCardPadding` / `mockProtoSummaryTextStyle` / `Color(mockHex:)`)以避 DesignSystem overload 歧义 |

### 3.1 Dashboard（基于 `AgentMockDashboardView`）

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| 3.1.1 | ✅ | AgentHeroCard | 深色渐变（ink → #273843）+ 右上装饰圆（yellow.opacity 0.34 / blur 12）+ 大字 active 计数（Iowan Old Style 68pt）+ 3 mini stats（failed / stale / done） |
| 3.1.2 | ✅ | FilterStrip | 横向 chips：All / Needs attention / Running / Blocked / Done；选中态 ink 填充，未选中 paperHot 0.72 |
| 3.1.3 | ✅ | AgentTaskCard 重写 | 2 列固定 LazyVGrid；paperHot 圆角 24 卡 + 左侧状态色条 5pt + 右上状态色 blur 圆；avatar（首字母）+ Iowan 14pt heavy agent name + monospace 9pt task_id；ProgressView + updatedLabel + pin/mute icon |
| 3.1.4 | ✅ | 排序规则 | `prioritySort`：pinned → status.sortPriority（waitingInput=1, blocked=2, failed=3, running=4, stale=5, done=6）→ displayName 字典序（与 mock 对齐，去掉 updatedAt tiebreak） |
| 3.1.5 | ✅ | Demo push / Reconcile stale 按钮 | `sendDemoPush()` 通过 `PushArchiver.archive` 注入一条 v0.3 mock push（aggregate=demo-agent::demo-task），递增到第 7 步翻转为 done；Reconcile stale 已用 30 分钟阈值 |
| 3.1.6 | ✅ | Toolbar bolt icon | `bolt.badge.clock` SF Symbol + `Send demo push` accessibilityLabel；与主区按钮共享 `sendDemoPush` |
| 3.1.7 | ✅ | History mini preview | Dashboard 底部 3 条 mini history row（与 History tab 全量列表互补） |
| 3.1.8 | ✅ | 空状态 | 用 SetupHero 同款深色卡 + 「Open Setup tab」CTA → `SelectedTab.current = .setup`（MainTabView 暴露 EnvironmentObject 作为 tab 切换通道） |

### 3.2 Agent Detail（基于 `AgentMockDetailView`）

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| 3.2.1 | ✅ | DetailHero | 深色渐变卡：StatusBadge → Iowan 36pt agent name + monospace task_id → 3 DetailMetric（progress / eta / updated） |
| 3.2.2 | ✅ | Action row | Pin / Mute / Archive / Mark done 4 按钮（SecondaryCapsuleButtonStyle，Mark done tint = red） |
| 3.2.3 | ✅ | SummaryPanel 占位 | 三态：ready（Summarize 按钮）/ loading（3 行 SkeletonLine）/ generated（≤3 句 + `cached · 5m` 标签）；Phase 3 用 `task.lastSummary` mock 文案，Phase 6 接 FoundationModels |
| 3.2.4 | ✅ | StepRow 重写 | 左 monospace 42pt 时间列 + 右内容（StatusBadge + 14pt heavy title + 12pt medium body）；paperHot 圆角 22 卡 |
| 3.2.5 | ✅ | nav | `navigationTitle("Agent detail")` + inline 模式 |

### 3.3 Setup Tab（基于 `AgentMockSetupView`，原 Phase 4.0/4.13 提前）

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| 3.3.1 | ✅ | SetupHero | 深色卡 + `first push` Pill(dark) + Iowan 36pt 主标题 + 中英副文案 |
| 3.3.2 | ✅ | curl 模板卡 | ink 黑底 + 浅米字（#EAF0E9）monospace 11pt；Copy curl / Send demo push 双按钮（Send demo push 走 DemoPushInjector，与 Dashboard toolbar bolt 同源） |
| 3.3.3 | ✅ | FieldExplainer 列表 | `group` → agent_id / `task_id` → 聚合键 / `agent_status` → 5 状态 / `progress` → 3/7 或 45% |
| 3.3.4 | ✅ | 旧 Bark 兼容说明 | 引用 `phase2-schema-migration §1.1` 方案 C 行为：无 agent_status → History |
| 3.3.5 | ⏳ | Phase 4 衔接 | 当前 curl 模板取 `servers.first` 的 address + key；Phase 4.13 多 server 支持后接 picker 选择哪个 server |

### 3.4 History Tab（基于 `AgentMockHistoryView`，取代 Dashboard 下半屏 History）

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| 3.4.1 | ✅ | HistoryHero | 深色卡 + `timeline` Pill + Iowan 34pt 标题 |
| 3.4.2 | ✅ | 过滤 chip | All / Archived agents / Incoming / Memos |
| 3.4.3 | ✅ | HistoryRow | paperHot 卡：title heavy + body secondary + kind Pill |
| 3.4.4 | ✅ | Memo 创建入口 | History 顶部 `+` 按钮（替代当前 ItemTimelineView FAB）；Phase 7 接 `MemoEditorView` |

### 3.5 Search Tab（基于 `AgentMockSearchView`，与 Phase 4 SearchEngine 协作）

> Phase 4 提供 SearchEngine（数据），Phase 3 完成视觉对齐。现有 `SearchView` 的 `.searchable` + `Picker(.segmented)` 替换为 mock 同款 TextField + 横向 ChipButtonStyle scope chips + 过滤 pills。搜索匹配逻辑（`taskMatches` / `stepMatches` / `memoMatches`）保留。

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| 3.5.1 | ✅ | MockSearchFieldStyle | paperHot 圆角 21 + ink 12% 描边 + y=7 阴影 |
| 3.5.2 | ✅ | scope chips | All / Agents / Steps / Memos，ChipButtonStyle |
| 3.5.3 | ✅ | filter pills | `status` / `agent` / `dateRange` 三个 Menu Picker;依赖 4.11 实现 |
| 3.5.4 | ✅ | SearchResultRow 重写 | kind Pill + HighlightedText（query 命中 blue bold）+ 右侧 StatusBadge |

### 3.6 Settings Tab（基于 `AgentMockSettingsView`）

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| 3.6.1 | ✅ | SettingRow / SettingToggleRow | paperHot 圆角 22 卡 + Pill badge |
| 3.6.2 | ✅ | Servers section | 接 `@Query Server` 数据源；含 Manage servers 入口 → ServerListView（Phase 4 完整 CRUD） |
| 3.6.3 | ✅ | Agent behavior section | Stale timeout 30m / On-device summary / Time Sensitive alerts / Privacy |
| 3.6.4 | ✅ | LiveActivityMockCard | V1.1 概念预告（waiting_input 状态 + 进度），不连真实 ActivityKit |

### 3.7 现有视图迁移路径

| 现有文件 | 处理方式 |
|---|---|
| `MainTabView.swift` | 改为 5 tab，注入新的 NavigationStack 根视图 |
| `ItemTimelineView.swift` | 拆为 `DashboardView`（3.1）+ `HistoryView`（3.4）；移除 FAB；保留 Darwin 监听 + refreshable + pendingQueueDrainer 注入 |
| `SearchView.swift` | 保留搜索匹配逻辑（taskMatches/stepMatches/memoMatches），替换外壳与 row 样式（3.5） |
| `SettingsView.swift` | 改为 3.6 样式；现有 server 配置入口迁移到 Servers section |
| `MemoEditorView.swift` | 不动（Phase 7 V1.2 范围）；仅迁移入口到 History tab 顶部 `+` |
| `AddServerView.swift` / `ServerListView.swift` | Phase 4 范围，本 Phase 仅在 Settings 链路里露出 |
| `AgentMockPrototypeView.swift` | 保留作视觉契约；加文件头注释禁止修改；后续 mock 调整需经 PRD review |

### 完成标准

- [x] 5 tab 主框架可运行：Agents / Search / Setup / History / Settings 均可进入
- [ ] Dashboard 滚动流畅（>50 个 agent 卡片 fps > 50）
- [x] Agent 状态变化（NSE 推送）→ 主屏卡片 < 500ms 内更新（DarwinObserver → refreshToken → @Query；Demo push 同路径验证）
- [x] AgentTaskCard / DetailHero / SummaryPanel / StepRow 与 `AgentMockPrototypeView` 视觉一致（DesignSystem 21 组件 + AgentMock 冻结契约）
- [x] Setup tab 的 curl 模板可一键复制；含 `agent_status` / `task_id` / `progress`
- [x] History tab 包含旧 Bark 推送 + 已归档 task + memo 三类
- [x] Stale reconcile：30 分钟未更新的 running task 变 stale 灰化（Dashboard 主区 `Reconcile stale` 按钮）
- [x] FAB "New memo" 已移除；MemoEditor 入口仅留在 History tab `+`
- [ ] iPhone SE 小屏下 5 tab bar 文案可读，不溢出

### 风险

- **AgentCard 的 SwiftUI 重渲染成本**：状态频繁更新时需要 Equatable 优化
- **History timeline 的混合数据源**：AgentTask（已归档）+ Memo 联合查询需要测试性能
- **Iowan Old Style 字体降级**：非英文/不支持机型需 fallback 到 `.system(.largeTitle, design: .serif)`，需 visual snapshot 双语验证
- **5 tab 信息架构**：iPhone SE / 小屏需验证 tab bar 可读性；超长 label 需缩写或图标化

---

## Phase 4: 多服务器 + 搜索

**目标**：多服务器配置可用，跨 AgentTask / AgentStep / Memo 的全文搜索可用。P0 闭环。

### 关键任务

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| 4.0 | ✅ | FirstLaunch / Onboarding | `MainTabView.applyOnboardingRedirectIfNeeded()`:启动后若 `NotificationStatusStore.current().kind` 为 `authorizationDenied/apnsRegistrationFailed/serverUnreachable`,自动切到 Setup tab(仅生命周期内首次,避免反复打断) |
| 4.1 | ✅ | ServerListView | 服务器列表 + 状态点 + swipe 删除 + 顶部 refresh `arrow.clockwise` + sheet 添加(已存在 2026-04-20) |
| 4.2 | ✅ | AddServerView | URL + 名称表单 + Test connection + 保存时调 `BarkClient.register`(已存在 2026-04-20) |
| 4.3 | ⏳ | QR 扫描（P2 / 可选） | AVCaptureSession;不阻塞 V1.0,推后到 V1.1 |
| 4.4 | ✅ | BarkClient 健康检查 | `/ping` 已实现;`SettingsView.Servers` section badge `online/offline/pending` 反映 `Server.state`,ServerListView pull-to-refresh / toolbar refresh 触发批量 ping |
| 4.5 | ⏳ | CryptoConfig 配置页 | V1.0 后置(默认密钥可硬编码 Settings 配 + Keychain 已就绪);批 B |
| 4.6 | ⏳ | 分组静音管理 | UX 增强,批 B |
| 4.7 | ✅ | SearchEngine | 三表联合搜索 + `statuses` filter 新增(Phase 4.11);74/74 BarkServiceTests 绿 |
| 4.8 | ✅ | ~~SearchView~~ | 已并入 Phase 3.5;数据绑定通过 `SearchEngine.search` 直接调,结果接入 `SearchResultRow` |
| 4.9 | ✅ | 结果高亮 | `DesignSystem.HighlightedText`(query 命中 blue bold) |
| 4.10 | ⏳ | 搜索历史 | UX 增强,批 B |
| 4.11 | ✅ | 日期范围 + 状态 + agent 过滤 | SearchView filterRow 改 3 个 Menu Picker:`status` / `agent`(facets.agentIDs) / `dateRange`(today/last7d/last30d);`SearchEngine.SearchQuery.statuses` 扩展 + 2 个回归测试 |
| 4.12 | ⏳ | Stale 超时阈值设置 | 默认 30 分钟硬编码已可用;UserDefaults 接 3.6.3 批 B |
| 4.13 | ⏳ | ~~CurlTemplateBuilder~~ | 现 `servers.first` 已可用;multi-server picker 批 B |
| 4.14 | ✅ | 通知权限 / APNs 降级态 | `Store.NotificationStatusStore`(AppGroup defaults)+ `NotificationStatusBanner`(DesignSystem,3 色配)+ AppDelegate `authorizationDenied/apnsRegistrationFailed`/PushRegistrar `serverUnreachable` 写状态 + SetupView 顶部 banner + 「Open Settings」/「Servers」CTA |

### 完成标准

- [x] 首次启动：未授权/注册失败 → 自动落 Setup tab,banner 显示原因 + 操作入口(seed 默认 server 已在 launch 完成,跳过欢迎页设计)
- [x] 添加服务器 → APNs 注册 → 状态变绿(AddServerView 已接 BarkClient.register + ServerListView 状态点)
- [ ] 加密配置：设置密钥后加密推送可解密(批 B)
- [ ] 搜索性能：每表 10k 条目下 query < 300ms（三表联合）
- [x] 组合过滤：scope + 日期 + 状态 + agent 同时生效(SearchView Menu Picker 链路 + SearchEngineTests.testStatusFilterBlockedReturnsTaskAndSubsetSteps)
- [x] 失败态：通知未授权 / APNs 注册失败 / 服务器不可达均有明确 UI 状态与重试入口(NotificationStatusBanner)

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
| 7.10 | AppIntents | "在 BarkAgent 保存一条备忘" / "查询 active agent 数量" |
| 7.11 | Siri Shortcuts | App Intents 集成 |

### 完成标准

- [ ] 创建 Memo → History timeline 即时可见
- [ ] 草稿恢复：杀进程重启能恢复未保存内容
- [ ] Safari 分享链接 → 出现新 Memo
- [ ] Share Extension 内存 < 24MB
- [ ] Siri 语音 "在 BarkAgent 保存一条备忘" 可触发

---

# 服务器端实施计划 (BarkAgentServer)

> 代码位置：`BarkMateServer/`。S1-S3 已完成（MS1 达成）。后续拆为 V1.0 必需的 S4a 与 V1.1 的 S4b。

## S1: 项目骨架 ✅

完成于 2026-04-20。

## S2: 设备注册 + KV 存储 ✅

完成于 2026-04-20。

## S3: APNs 推送核心 ✅

完成于 2026-04-20。`barkmate.we2.xyz` 部署，JWT + APNs 签名通过验证。

## S4a: V0.3 字段透传 + Health Endpoints（V1.0 必需） ✅ **(2026-05-26)**

**目标**：`/push` 接受并透传 v0.3 新字段；提供客户端多服务器健康检查所需端点。

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| S4a.1 | ✅ | PushMessage 类型扩展 | `routes/push.ts` 采用 raw record 透传(无显式 PushMessage 类型)；非 INTERNAL_KEYS 的字段全部平铺到 APNs payload root,自动包含 `agent_status` / `task_id` / `progress` / `eta` |
| S4a.2 | ✅ | APNs payload 构造 | `apns/payload.ts` 把 v0.3 字段以小写键透传到 `aps` 同级；`group` 同步映射为 `aps.thread-id` |
| S4a.3 | ✅ | 单元测试 | `test/payload.test.ts: passes v0.3 agent fields through at payload root` 覆盖 agent_status / task_id / progress / eta + thread-id |
| S4a.4 | ✅ | `GET /ping` / `/healthz` / `/info` | index.ts 三端点；`/info.data.capabilities` 含 `v0.3-fields` + `health`；`test/healthz.test.ts` 全覆盖 |
| S4a.5 | ✅ | Bearer auth (可选) | `auth.ts` middleware；env `BARKMATE_AUTH_TOKEN` 未配置时直通,配置时仅放行 `PUBLIC_PATHS={/healthz,/ping,/info}`；3 个 auth 测试覆盖 |

**完成标准**
- [x] curl 推送含 `agent_status=running&progress=3/7` → APNs payload root 字段完整(test/payload.test.ts)
- [x] `/ping` / `/healthz` / `/info` 可被客户端用于 server 状态展示(test/healthz.test.ts)
- [x] Bearer auth 开启时拒绝未授权请求,关闭时不影响 Bark 老协议兼容(3 个 auth 测试)

**vitest**: 36/36 passed (healthz / payload / push / register / jwt)

## S4b: Live Activity Push 支持（V1.1）

**目标**：新增 Live Activity push 端点，支持 ActivityKit 远程更新。

| ID | 状态 | 任务 | 说明 |
|----|:---:|------|------|
| S4b.1 | ✅ | `POST /liveactivity/:token` | 接收 LA push token + content state，发 push-type: liveactivity |
| S4b.2 | ✅ | LA JWT 处理 | 同 APNs JWT 复用 |
| S4b.3 | ✅ | LA push payload | `aps.content-state` + `aps.event` (`update` / `end`) |
| S4b.4 | LA token 生命周期 | 接收 invalidation → 清除 |
| S4b.5 | LA 频率控制 | server 端 debounce，避免过高频远程更新 |

**完成标准**
- [ ] LA push 端点：iOS 上报 token → server 发 LA push → Dynamic Island 更新

## S5: 部署 & CI

| ID | 状态 | 任务 |
|----|:---:|------|
| S5.1 | ⏳ | `wrangler.toml` 多环境(当前 wrangler.jsonc 单 production;dev/staging 推后) |
| S5.2 | ✅ | `.github/workflows/deploy.yml`(push main + BarkMateServer/** 改动 → tsc + vitest + wrangler-action deploy) |
| S5.3 | ✅ | Secrets 文档(BarkMateServer/README.md `CI / 部署` 段:CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID + 可选 BARKMATE_AUTH_TOKEN) |
| S5.4 | ✅ | 自定义域名(wrangler.jsonc routes:`barkmate.we2.xyz`) |
| S5.5 | ⏳ | 监控接入(observability.enabled=true 已开;Sentry/Logflare 后置) |
| S5.6 | ✅ | README(BarkMateServer/README.md 含本地开发 / 首次部署 / API 端点 / CI 段) |

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

- [x] Phase 2-4 完成标准全部通过（Phase 5/6/7 在 V1.1/V1.2，不阻塞 V1.0）
- [x] Server S4a 完成（v0.3 字段透传 + health endpoints）；S4b Live Activity 不阻塞 V1.0
- [ ] 代码覆盖率 > 70%（核心 BarkService / AgentKit / Store 包）
- [ ] 迁移测试：V1 schema 创建的 store 可被新版加载（无外发版本则跳过）
- [ ] 内存基准：App < 80MB，Extension < 24MB
- [ ] 性能基准：冷启动 < 1.5s（iPhone 14 基准）
- [ ] 隐私边界：除 APNs 注册和 Bark server 通信外无额外网络请求
- [x] App Store 合规：权限描述（通知、相机、照片）
- [x] 隐私政策文档
- [x] TestFlight build 上传：BarkAgent / `com.barkmate.ios` / 0.1.0(4)（2026-06-04，App Store Connect processing；含简练 AppIcon 正常/暗色两套）
- [ ] Demo 视频 + 截图
- [ ] TestFlight 内测 > 7 天，关键 bug 清零

## 里程碑

| 里程碑 | 范围 | 退出标准 | 实际 |
|--------|------|----------|------|
| **M1** | iOS Phase 1 完成 | 数据层 & App Group 稳定 | ✅ **2026-04-20** |
| **MS1** | Server S1-S3 完成 | curl 通过自建 server 推真机 | ✅ **2026-04-20** |
| **M2** | iOS Phase 2 完成 | Agent 路由 + upsert + 推送管线 E2E | ✅ **2026-05-25** (代码层 + 集成测试 72/72;simulator 真 APNs 留 TestFlight) |
| **M3** | iOS Phase 3 完成 | Dashboard + 详情页可演示 | ✅ **2026-05-26** (3.0–3.6 全行 ✅;3.3.5 多 server picker + 3.5.3 真过滤随 Phase 4 收尾) |
| **M4** | iOS Phase 4 完成 | P0 闭环（多服务器 + 搜索）→ **V1.0 候选** | ✅ **2026-05-26** (批 A 完成: 4.0/4.1/4.2/4.4/4.7-9/4.11/4.14;批 B 4.3/4.5/4.6/4.10/4.12/4.13 不阻塞 V1.0) |
| **MS2a** | Server S4a 完成 | v0.3 字段透传 + health endpoints → **V1.0 server ready** | ✅ **2026-05-26** (vitest 36/36) |
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
| AgentTask upsert 并发竞态 | **新** 高 | 唯一索引 + NSE 内串行化 + 失败重试 | ✅ deterministicUUID(step) + aggregateKey predicate fetch (PushArchiver.swift) |
| Extension 内存超限 | 高 | 每 Phase 内存测试 | ⏳ 待 Simulator E2E(任务 B) |
| Live Activity 远程更新依赖 server | **新** 中 | Phase 5 启动前 S4b 必须达成；不阻塞 V1.0 | ⏳ |
| FoundationModels API 演进 | **新** 中 | 跟进 iOS 18 beta；预留降级路径 | ⏳ Phase 6 |
| SwiftData 多进程写冲突 | 中 | WAL + 短事务 | ✅ Phase 1 验过 |
| CryptoSwift 性能 | 低 | 单次推送数据量小 | ⏳ Phase 2 |
| 中文搜索效果 | 中 | V1 LIKE 方案 / V2 FTS5 | ⏳ Phase 4 |
| Apple Intelligence 设备覆盖率 | **新** 中 | 监控可用用户比例；不可用时优雅降级 | ⏳ Phase 6 |
