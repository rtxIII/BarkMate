# BarkAgent — 实施计划

> 版本: 0.5.0 | 日期: 2026-07-22 | 状态: Draft（glance-first 大重构 · 配合 product.md / design.md v0.5.0）

## 0. 本次重写说明

旧 plan.md（v0.4.1）已退化为 22 行残桩且是双端 Server 视角。v0.5 重写为 **glance-first 三阶段实施计划**，聚焦 iOS 客户端 `BarkMate/`，对齐真身代码。

**目标**：把重心从「打开 app 看 dashboard」搬到「不打开也能瞄」，治三句抱怨：状态变 UI 不动 / History 没用 / 信息太多。

**顺序（已拍板）**：**G1 → G2 → G3**。理由：G1 纯增量、风险最低、最快见效且不碰 IA；G2 动 IA 结构；G3 跨端依赖最重放最后。

**基线**：测试 101 个（App/Tests + 各 Package/Tests）；每阶段出口条件含"测试全绿 + 新增用例覆盖"。

```
G1  Glance 新鲜度        —— P0，最小闭环，1 条工作线                 ~0.5-1d
     └ 治「状态变 UI 不动」：NSE 落库即 reloadTimelines
G2  IA 瘦身 2-Tab        —— P0，动 UI 结构                          ~1-1.5d
     └ 治「信息太多 / History 没用」：History 折进 Agents
G3  Live Activity        —— 本地链 P0 · 远程冷态 P1（依赖 Server）    ~2-4d
     └ 深化「离桌感知」：锁屏一等公民（app 运行时本地链先交付）
```

---

## G1 — Glance 新鲜度（P0）

> **治**：状态变了，锁屏/Widget 不动。
> **根因**（design §0.2）：全工程无任何 `WidgetCenter.reloadTimelines` 调用；NSE 已写库（数据新鲜）但 glance 表面无人捅，只能 10 分钟轮询。
> **策略**：纯增量。落库成功后追加一次轻量 Widget 刷新，放 NSE（app 未开也跑）是"离桌即时"的关键。

### G1.1 抽 Widget kind 共享常量

- **现状**：`Widgets/Sources/BarkMateWidgets.swift` 里 `kind = "ActiveAgentsWidget"` 是字面量，NSE 拿不到。
- **动作**：在 `Store`（或 Models 常量文件）加 `public enum WidgetKind { public static let activeAgents = "ActiveAgentsWidget" }`，Widget target 改引用该常量。
- **验证**：Widget 仍能正常注册；`grep` 确认无第二处字面量。

### G1.2 NSE 落库后刷 Widget

- **落点**：`NotificationServiceExtension/Sources/NotificationService.swift` 的 `processPipeline` switch。
- **动作**：`.archived` / `.pending` 分支，`DarwinNotification.post(.itemDidArrive)` 之后追加：
  ```swift
  WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.activeAgents)
  ```
- **约束**：`import WidgetKit`；刷新失败不阻断 `contentHandler`（尽力而为）。
- **验证**：真机推一条 `agent_status=blocked` → 不打开 app，锁屏/主屏 Widget 计数即时变化。

### G1.3 主 app 侧 upsert 补刷（一致性）

- **落点**：主 app 内所有"落库后发 Darwin"的点，同步补 Widget 刷新，避免只有推送路径新鲜：
  - `App/Sources/Views/AgentDashboardView.swift` — `sendDemoPush()` 后
  - `App/Sources/Views/SetupView.swift` — demo push 后（`DemoPushInjector.injectNextStep` 处）
  - `App/Sources/PendingQueueDrainer.swift` — drain 落库后
- **动作**：抽一个 `GlanceRefresh.reload()` 小工具（封 `WidgetCenter.shared.reloadTimelines(ofKind:)`），三处共用，避免散落。
- **验证**：demo push / drain 后 Widget 同步刷新。

### G1.4 测试

- **新增**：`PushPipeline` 集成测试补一条断言——`.archived` 后 glance 刷新被触发（用可注入的 `GlanceRefreshing` protocol + spy，避免测试依赖真实 WidgetKit）。
- **回归**：现有 101 测试全绿。

### G1.5 Stale 阈值默认改 15min（老板决策）

- **现状**（`Packages/Models/Sources/Models/Enums.swift`）：
  ```swift
  StaleThresholdCatalog.options = [.off, .minutes(10), .minutes(30), .minutes(60), .minutes(120)]
  StaleThresholdCatalog.defaultThreshold = .minutes(30)
  ```
- **动作**：`.minutes(15)` 插入 options → `[off,10,15,30,60,120]`；`defaultThreshold` 改 `.minutes(15)`。
- **理由**：Claude Code 这类会话式 agent，15min 无上报更贴近"可能已死"的判断。
- **注意**：`.minutes(15)` 必须在 options 里，否则默认值会成为 picker 选不出的孤值。
- **测试**：`StaleTimeoutStoreTests` 更新默认值断言 + options 含 15 的用例。
- **验证**：全新安装默认阈值 15min；picker 可选 15。

### G1 出口条件

- [ ] NSE / 主 app 三处 upsert 后均触发 Widget 刷新
- [ ] Widget kind 单一常量源，无字面量漂移
- [ ] 真机验证：不打开 app，推送到达后 Widget 计数即时变化
- [ ] Stale 默认 15min + picker 含 15 选项
- [ ] 测试全绿 + 新增 glance 刷新用例 + stale 默认值用例

---

## G2 — IA 瘦身 2-Tab（P0）

> **治**：信息太多 / History 独立 Tab 是负债。
> **策略**：History Tab 内容折进 Agents 的 Settled 段；Tab 从 3 → 2（Agents + Settings）。UI 结构变更，需谨慎保留已了结/归档/旧协议消息的可达性。

### G2.1 Dashboard Settled 段吸收 History 内容

- **现状**：
  - `AgentDashboardView` 已有三桶，Settled = `done`/`failed`/`stale`（活跃未归档）。
  - `HistoryView` 额外承载：**已归档 AgentTask** + **旧协议 `AgentInboxItem`（[BARK]）** + STALE heads-up 段 + 按日期分组 + 清除历史。
- **动作**：把 History 独有的两类数据并入 Dashboard 的 Settled 段/展开区：
  - Settled 段增加"已归档"分区（或折叠子段），复用 `HistoryItemData.fromTask` / `fromInboxItem` 的映射逻辑。
  - 旧协议 `AgentInboxItem`（[BARK] 徽章）归入 Settled 段底部。
  - "清除历史"动作迁到 Settled 段的段头菜单（保留 `clear(olderThan:)` 逻辑）。
- **保留**：stale 派生（`effectiveStatus`）、pinned 保护、project 分组折叠不变。
- **验证**：归档一个 task → 仍能在 Agents 内找到；旧协议消息可见；清除历史可用。

### G2.2 删 History Tab

- **落点**：`App/Sources/Views/MainTabView.swift`
- **动作**：
  - `enum AppTab` 删 `.history`（剩 `.agents` / `.settings`）。
  - `tabItems` 删 History 项（剩 2 项）。
  - `tabContent` switch 删 `case .history`。
  - `HistoryView.swift` **暂保留文件**（其映射/清除逻辑被 G2.1 复用；确认无引用后于 G2.4 决定是否删除）。
- **验证**：app 启动只剩 2 Tab；无编译残留引用。

### G2.3 空态 / 落地体验

- **动作**：Settled 段吸收历史后，确认空态文案合理（无任何 agent 时的 empty state 不被历史分区破坏）。
- **验证**：全空 → 正确空态；仅有归档 → Settled 段可见、needs-you/running 空。

### G2.4 清理与测试

- **动作**：G2.1 迁移完成且无引用后，评估 `HistoryView.swift` 去留（倾向删，逻辑已内联到 Dashboard；若保留需注明理由）。
- **测试**：
  - 更新 `MainTabView` 相关测试（`SelectedTabTests` 等）适配 2 Tab。
  - 新增 Settled 段吸收归档/inbox 的映射测试（复用 `DashboardMappingTests` 风格）。
  - UITest 适配：tab 数量、History 入口消失。
- **回归**：全绿。

### G2 出口条件

- [ ] app 只剩 2 Tab（Agents + Settings）
- [ ] 已归档 task / 旧协议 [BARK] 消息 / 清除历史 均在 Agents 内可达
- [ ] stale 派生 + project 分组 + pinned 保护不回归
- [ ] 空态正确
- [ ] 测试全绿（含 tab 数量 UITest 适配）+ 新增映射用例

---

## G3 — Live Activity（本地链 P0 · 远程冷态 P1）

> **深化**：让 needs-you 的 agent 成为锁屏一等公民（Dynamic Island）。
> **现状**（design §9）：`LiveActivityExtension` target 不存在；仅 `AgentTask.liveActivityID` 字段 + Models ActivityAttributes 空壳。
> **拆分（老板决策"动态 LA 直接上"）**：G3.1-G3.3 = **本地链 P0**（app 运行时起/更/闭 LA，跟着 G1/G2 做）；G3.4 = **远程冷态 P1**（app 被杀时靠 Server LA push，依赖 BarkMateServer 跨端）。

### G3.1 新建 LiveActivityExtension target（P0）

- **动作**：`project.yml` 加 `LiveActivityExtension`（app-extension，widget-extension 类型）；App Group 同 `group.com.barkagent.shared`。
- **内容**：`AgentActivityAttributes` 正式定义（design §9.1）+ Dynamic Island / 锁屏 LA UI（MissionControl 配色）。
- **验证**：target 编译；LA UI 预览可渲染。

### G3.2 主 app 侧 LA 协调器（P0）

- **动作**：新建 `ActivityCoordinator`（主 app）：
  - 订阅 `AgentTask` 变化（@Query / Darwin）。
  - 规则（方案 X）：`waiting_input`/`blocked` 的 (agentID+taskID) → `Activity.request` 起 LA；转 running/done/failed/stale/归档 → `end`；cap 4 + LRU。
  - 写回 `AgentTask.liveActivityID`。
- **约束**：`Activity.request` 只能主 app 前/后台调（NSE 不能）。
- **验证**：本地状态流转驱动 LA 启停正确。

### G3.3 NSE 侧 LA update（P0）

- **动作**：NSE 落库后，若 task 有活跃 `liveActivityID` → `Activity.update(...)`（更新 content state）；终态 → `end`。
- **约束**：NSE 只 update/end，不 request（首启缺失时落 PendingQueue，主 app 补起）。
- **验证**：app 后台时，推送能更新已存在 LA。
- **边界诚实标注**：app **被系统完全杀掉**时，主 app 不跑、NSE 也无法唤醒已冻结的 LA → 这种冷态更新走不通，必须靠 G3.4 远程 push。本地链到此为止。

### G3.4 远程 LA push（P1 · 跨端，依赖 Server）

- **动作**：
  - 主 app：`activity.pushTokenUpdates` → 写 App Group + 上报 BarkMateServer。
  - **BarkMateServer**：新增 `liveactivity` push-type 端点，task 有活跃 token 时同发 LA push（Server 侧独立工作项）。
- **验证**：app 完全未运行时，server LA push 直接更新锁屏 LA。

### G3.5 PendingQueue 扩展 + 测试

- **动作**：`PendingQueue` 任务类型扩 `startLiveActivity` / `endLiveActivity`（NSE 无法直启，交主 app drain）。
- **测试**：LA 启停规则单测（cap/LRU/状态映射）；LA update/end 路径测试。
- **回归**：全绿。

### G3 出口条件

**本地链（P0）：**
- [ ] LiveActivityExtension target 落地，Dynamic Island + 锁屏 LA 可显示
- [ ] needs-you 状态自动起 LA，状态流转自动 end（cap 4 + LRU）
- [ ] app 运行（前/后台）时，NSE 能 update 已存在 LA；首启缺失走 PendingQueue 主 app 补
- [ ] 测试全绿 + LA 规则单测

**远程冷态（P1）：**
- [ ] （跨端）Server LA push 端点就绪 → app 被杀时也能更新锁屏 LA

---

## 附录 A — 阶段依赖与并行

```
G1 (glance 刷新) ──► G2 (2-Tab) ──► G3 (Live Activity)
   独立·纯增量        动 UI 结构      跨端·最重

可并行：
- G3.4 的 BarkMateServer LA push 端点 → 与 G1/G2 iOS 工作并行推进（不同代码库）
- 各阶段测试用例编写与实现同步（TDD）
```

## 附录 B — 风险与缓解

| 风险 | 阶段 | 缓解 |
|------|------|------|
| NSE 24MB/30s 预算 | G1 | `reloadTimelines` 是轻量信号，排在解密/图片之后；失败不阻断 |
| History 内容迁移丢可达性 | G2 | 出口条件强制校验归档/inbox/清除三条路径 |
| UITest 因 tab 数变更批量失败 | G2 | 先改 UITest 预期再删 tab；预留既有 UI 测试失败清账 |
| NSE 不能 `Activity.request` | G3 | 首启靠主 app / server push；NSE 只 update/end |
| Server LA push 跨端未就绪 | G3 | G3.1-G3.3 本地链先交付（app 运行时可用），G3.4 待 server |

## 附录 C — 与文档的一致性

- 价值主张 / IA / 场景：见 `product.md` v0.5.0
- 技术方案 / 三条工作线 / 真身校正：见 `design.md` v0.5.0
- 本 plan 的 G1/G2/G3 ↔ design 的线 A/线 B/线 C 一一对应
