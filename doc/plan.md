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
- **验证**：真机推一条 `agent_status=blocked` → 不打开 app，主屏 Widget（systemSmall/Medium）计数即时变化。
- **细节**：`reloadTimelines(ofKind:)` 是"请求非保证"——系统按预算合并刷新，高频推送不会 1:1 触发。这是可接受的，不要为"保证每条都刷"去绕过系统预算（会被限流）。

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

### G1.6 补锁屏 Widget（accessory family）

- **缺口**：原型 L0 画了锁屏 Widget，但真身 `BarkMateWidgets.swift` 只声明 `.supportedFamilies([.systemSmall, .systemMedium])` —— **锁屏 Widget 属于 accessory family，代码里完全没有**。锁屏是 glance 主战场的一等表面，不能只在原型里。
- **动作**：
  - `ActiveAgentsWidget.supportedFamilies` 追加 `.accessoryRectangular`（锁屏矩形：`N wait · M run · K settled` 摘要）+ 可选 `.accessoryInline`（锁屏顶部单行）。
  - 新增对应 view 分支（`.accessoryRectangular` → `AccessoryRectangularWidgetView`），用 `.widgetAccentable()` 适配锁屏染色渲染模式。
  - `containerBackground` 在 accessory family 下需返回空/透明（锁屏 widget 无背景）。
- **约束**：accessory 渲染是**单色染色**模式，HUD 多色（amber/cyan/lime）在锁屏会被系统压成 accent 单色 —— 设计上靠"数字大小 + 位置"区分三桶，不靠颜色。原型的多色锁屏 Widget 是示意，落地要接受这个系统约束。
- **测试**：真身无 widget 测试 target / 无快照基建;accessory 是纯渲染层,依 BarkMateWidgets 编译 + `#Preview` 渲染验证,运行呈现走真机锁屏(决策同 G1.4 轻量策略,不为渲染层引入快照基建)。
- **验证**：真机锁屏添加 widget → 显示三桶计数 + G1.2 推送即时刷新覆盖 accessory family。

### G1 出口条件

- [ ] NSE / 主 app 三处 upsert 后均触发 Widget 刷新（覆盖 system + accessory family）
- [ ] Widget kind 单一常量源，无字面量漂移
- [ ] 真机验证：不打开 app，推送到达后主屏 + 锁屏 Widget 计数即时变化
- [ ] 锁屏 Widget（accessoryRectangular）落地，接受单色染色约束
- [ ] Stale 默认 15min + picker 含 15 选项
- [ ] 测试全绿 + 新增 glance 刷新用例（WidgetKind 契约值）+ stale 默认值用例；accessory 走编译 + `#Preview`（无快照 target）

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
- **文案对齐**：`SettingsView.swift:71` 的 Stale timeout 描述现为 `Running > this window → auto-demote to History · Stale.`。History Tab 删除后「to History」指向已不存在的独立入口，需改为 `→ auto-demote to Settled · Stale.`（同步改原型 prototype.html 第 790 行占位文案，避免文档漂移）。
- **验证**：归档一个 task → 仍能在 Agents 内找到；旧协议消息可见；清除历史可用；Settings stale 描述不再指向 History Tab。

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
- [ ] Settings「Stale timeout」描述不再指向已删除的 History Tab（改指 Settled）
- [ ] stale 派生 + project 分组 + pinned 保护不回归
- [ ] 空态正确
- [ ] 测试全绿（含 tab 数量 UITest 适配）+ 新增映射用例

---

## G3 — Live Activity（本地链 P0 · 远程冷态 P1）

> **深化**：让 needs-you 的 agent 成为锁屏一等公民（Dynamic Island）。
> **现状**（design §9）：无独立 LA target；仅 `AgentTask.liveActivityID` 字段 + Models ActivityAttributes 空壳。真身已有 `BarkMateWidgets` target 可承载 LA（见 G3.1）。
> **拆分（老板决策"动态 LA 直接上"）**：G3.1-G3.3 = **本地链 P0**（app 运行时起/更/闭 LA，跟着 G1/G2 做）；G3.4 = **远程冷态 P1**（app 被杀时靠 Server LA push，依赖 BarkMateServer 跨端）。

### G3.1 Live Activity UI（并入现有 Widgets target，不新开 target）

- **落地修正**：不新建独立 `LiveActivityExtension` target。真身**已有 `BarkMateWidgets` target**（widget-extension），Apple 允许 Live Activity 的 `ActivityConfiguration` 与普通 Widget **同处一个 widget bundle** —— 直接把 LA 声明加进 `BarkMateWidgets`，省一个 target、省一份 Info.plist / entitlements / 签名配置。
- **动作**：
  - `AgentActivityAttributes` 正式定义（design §9.1）放 `Packages/Models`（主 app 与 widget 都要用），替换现有空壳。
  - `BarkMateWidgets.swift` 的 `WidgetBundle.body` 追加 `AgentLiveActivity()`（一个 `ActivityConfiguration`），含 Dynamic Island（compact/minimal/expanded 三区）+ 锁屏 LA UI（MissionControl 配色）。
  - Info.plist 加 `NSSupportsLiveActivities = YES`（主 app target，不是 widget target）。
- **约束**：Dynamic Island 各区有尺寸上限，expanded 区才放 step 详情，compact 只放 status glyph + 进度 —— 原型的 DI 卡是 expanded 态示意。
- **验证**：target 编译；LA UI 用 `#Preview` 渲染；Info.plist `NSSupportsLiveActivities` 就位。

### G3.2 主 app 侧 LA 协调器（P0）

- **动作**：新建 `ActivityCoordinator`（主 app）：
  - 订阅 `AgentTask` 变化（@Query / Darwin）。
  - 规则（方案 X）：`waiting_input`/`blocked` 的 (agentID+taskID) → `Activity.request` 起 LA；转 running/done/failed/stale/归档 → `end`；cap 4 + LRU。
  - 写回 `AgentTask.liveActivityID`。
- **约束**：`Activity.request` 只能主 app 前/后台调（NSE 不能）。
- **验证**：本地状态流转驱动 LA 启停正确。

### G3.3 本地链 LA update（P0 · 由主 app coordinator 承担,非 NSE）

- **修正（已验证的 ActivityKit 约束）**：原设想「NSE 落库后 `Activity.update`」**不成立**。`Activity<T>.activities` 是**进程隔离**的——NSE 是独立进程,其 `activities` 恒为空,无论 app 前台/后台/被杀都拿不到主 app 起的 LA,故 **NSE 根本无法 update/end LA**（Apple 论坛 + 文档确认;唯一后台更新通道是 ActivityKit push = G3.4）。
- **动作**：更新逻辑并入 `ActivityCoordinator.reconcile()`（G3.2）：对仍在 desired 且已有 LA 的 task,`Activity.update(...)` 把 content state 刷到最新；离开 needsYou/归档 → `end`。NSE 侧**不碰 Activity**,只保留 DB 落库 + Darwin `.itemDidArrive` + widget 刷新（G1）。app 收到 Darwin(前台/活跃)即 reconcile 更新;冷启动 `start()` 补齐。
- **约束**：`Activity.request`/`update`/`end` 全部只能主 app 进程调。
- **验证**：app 前台时推送到达 → LA content state 随之更新;归档/转 running → LA 结束。
- **边界诚实标注**：app **挂起或被系统杀掉**时主 app 不跑,NSE 又无法 update → 本地链更新**只覆盖前台/活跃**;后台/冷态更新必须靠 G3.4 远程 push。本地链到此为止。

### G3.4 远程 LA push（P1 · 跨端，依赖 Server）— 已落地（自动 fan-out）

- **动作（已实现）**：
  - 主 app：`startActivity` 加 `pushType: .token`,`activity.pushTokenUpdates` → 上报 BarkMateServer `/liveactivity/register`（`{device_key, aggregate_key, token}`）；LA end 时上报 `token=deleted` 注销。落库不写 `sourceServerID`(生产恒 nil)→ 改向**所有已注册 Server 全量登记**,每台仅在自己 KV 命中该 aggregateKey 时 fan-out,冗余无副作用。
  - **BarkMateServer**：`la:<device_key>:<aggregate_key>` KV 存 LA push token；`POST /liveactivity/register` 登记/注销；`/push` 命中带 `agent_status` 的推送时,由 `agent_id`+`task_id` 复算 aggregateKey → 查 LA token → best-effort 追发一条 `liveactivity` 远程更新（`done`/`failed` → `event:end` 且清理登记,其余 → `event:update`；content-state 与 iOS `AgentActivityAttributes.ContentState` 对齐,纯字符串 status/stepTitle/progress）。fan-out 失败不影响 alert 推送返回码。
- **验证（已通过）**：server vitest 59 例全绿（含 register 4 + fan-out 4）+ `tsc --noEmit` clean；iOS app BUILD SUCCEEDED + BarkMateTests 23 例 0 失败；server 已部署生产（`barkagent.we2.xyz`,version `d3e1ed6b`,`/info` capabilities 含 `liveactivity`）。
- **端到端待办**：「app 未运行 → server LA push 更新锁屏」需在 Xcode 签名构建下跑（**模拟器即可**——Apple Silicon/T2 + macOS 13+/Xcode 14+ 的模拟器支持 LA pushToken 与 `liveactivity` 远程推送；本仓库 CI/本地无签名环境跑不了,故非本会话可验）。当前 fan-out 打 APNs **sandbox**,只认 Xcode 直装 debug 构建的 token。

### G3.5 PendingQueue 扩展 + 测试

- **PendingQueue 扩展 → 不需要（G3.3 修正的连锁结论）**：原设想「NSE 无法直启 LA,故用 PendingQueue 排 `startLiveActivity`/`endLiveActivity` 命令交主 app drain」。但 `ActivityCoordinator.reconcile()` 是**幂等**的——每次从 DB 全量派生 desired LA 集合(cap/LRU),NSE 写库 + Darwin `.itemDidArrive`(或冷启动 `start()`)触发 reconcile 即覆盖「NSE 写了 needsYou 任务 → app 恢复后起 LA」。**无需命令队列**;状态即真相,不需要把「起/停」当命令排队。
- **测试(已落地)**：`ActivityPolicyTests`(App/Tests) 覆盖 cap4 / LRU / 状态映射(needsYou 判定) / start·end·update 计划,纯函数确定性单测,8 例全绿。
- **回归**：全绿(BarkMateTests 23 例 0 失败)。

### G3 出口条件

**本地链（P0）：**
- [ ] Live Activity 并入 `BarkMateWidgets` bundle（不新开 target），Dynamic Island（compact/minimal/expanded）+ 锁屏 LA 可显示
- [ ] Info.plist `NSSupportsLiveActivities = YES` 就位
- [ ] needs-you 状态自动起 LA，状态流转自动 end（cap 4 + LRU）
- [ ] app 前台/活跃时,coordinator reconcile 把已有 LA 的 content state 刷到最新（NSE 进程隔离无法 update,已验证）
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

## 附录 D — 原型示意 vs 产品功能（防止照搬装饰当 feature）

`doc/mock/prototype.html` 是**叙事演示**，部分元素是为讲清价值而加的示意，**不是要落地的功能**。开发时按此表区分：

| 原型元素 | 性质 | 落地处置 |
|----------|------|----------|
| 雷达遥测台（扫描环 / 坐标网格 / PUSH LATENCY 220ms / LA TOKENS 3）| **纯演示装饰** | **不做**。填 demo 负空间用；app 内无此面板，那些读数也非真实指标 |
| 状态码 / 徽章辉光（text-shadow glow）| **视觉语言** | **做**，落到 DesignSystem。但注意 §G1.6：锁屏 accessory family 是单色染色，多色辉光在锁屏无效 |
| `stale` 徽章刻意不发光 | **设计决策** | **做**。"发光=活着/熄灭=可能死了"，`stale`/`.b-stale` 保持 inkMute 无 glow，是有意的语义 |
| Dynamic Island expanded 大卡 | **示意 expanded 态** | **做**，但 compact/minimal 区受尺寸限制只能放 glyph+进度（见 G3.1 约束） |
| 锁屏多色 Widget（amber/cyan/lime 三色计数）| **示意** | 落地受 accessory 单色约束（G1.6），靠数字大小/位置区分桶，非颜色 |
| 环境光晕（手机 radial glow）| **demo 舞台光** | **不做**。真机锁屏无此效果，纯为原型三列平衡 |
| Settings「Glass」音效名 / 「api.day.app」等示例数据 | **占位** | 用真实 `SoundCatalog` / 用户实际 server 数据替换 |

> 一句话原则：**辉光是语言（做）、遥测台是布景（不做）**。照搬布景进 app 会引入不存在的指标和面板。
