# BarkAgent Phase 2 手动测试验证方案

> 版本: 1.0 | 日期: 2026-05-21 | 范围: Phase 2.0 Schema 重构完成 + Phase 3.0 视觉对齐完成后的手动验证
> 阻塞依赖: Phase 2.1–2.4 / 2.9–2.14 (⏳) — 真实 APNs/NSE/解密/Darwin 通知相关用例本轮**跳过**

## 0. 测试环境

| 项 | 设置 |
|---|---|
| Xcode | 项目当前支持版本 |
| Simulator | iPhone SE (3rd) / iPhone 15 Pro / iPhone 15 Pro Max |
| iOS 版本 | 17.0 基线 + 18.x (FoundationModels available 判断) |
| 设备 | **Simulator only**（真机推送依赖 ⏳ Phase 2.1–2.4） |
| 截图归档 | `doc/screenshots/phase2/{L1,L2,L3,L4}/` |
| 数据态 | 每个 L 用例前 reset Simulator 数据，App Group 清空 |

## 1. 前置自动化基线（L5 提前自检）

执行以下命令，**任一失败则阻断手动测试**：

```bash
# Models 包
cd BarkMate/Packages/Models && swift test
# 预期: 11/11 绿

# BarkService 包
cd ../BarkService && swift test
# 预期: 63/63 绿
```

记录通过时间戳到 report `自动化基线` 段。

---

## L0 · 工程基线（必过 / blocker）

| 用例 | 步骤 | 预期 |
|---|---|---|
| L0-1 编译 | Xcode 选中 `BarkAgent` scheme，Simulator=iPhone 15 Pro，Build | 无 error/warning（已知 warning 列入 report 备注） |
| L0-2 启动 | Run | App 启动 < 1.5s，落在 Agents tab（默认） |
| L0-3 四 target | 分别 select `ShareExtension` / `NotificationServiceExtension` / `Widgets` scheme，Build | 均成功 |
| L0-4 App Group | 主 App 写一条 Memo（History tab `+`），杀进程重启 | Memo 仍在 |
| L0-5 Keychain | （观察）首次启动无 Keychain 错误日志 | console 无 `errSecMissingEntitlement` |

---

## L1 · 5 Tab 信息架构走查（Phase 3.0 验收）

依次 tap 每个 tab，三尺寸 Simulator 各跑一遍并截图。

| 用例 | 步骤 | 预期 | 截图 |
|---|---|---|---|
| L1-1 Tab 数 | 查看 tab bar | 5 项：Agents / Search / Setup / History / Settings | `L1/tabbar-{SE,15Pro,15ProMax}.png` |
| L1-2 选中态 | tap 每 tab | 选中态使用 `.tint(.ink)`，与 mock 一致 | 同上 |
| L1-3 SE 不溢出 | iPhone SE | 5 个 label 不被截断，必要时图标化 | `L1/tabbar-SE.png` |
| L1-4 FAB 移除 | 查看 Agents/History | 不存在悬浮 "New memo" FAB | `L1/no-fab.png` |
| L1-5 Memo 入口 | History tab 顶部 | 仅在此处有 `+` 进入 `MemoEditorView` | `L1/history-plus.png` |
| L1-6 ItemTimelineView 已删 | grep 源码 | `ItemTimelineView.swift` 不存在 | report 文本验证 |

---

## L2 · AgentMockPrototypeView 契约对齐

参照 `BarkMate/App/Sources/Views/AgentMock/AgentMockPrototypeView.swift`（契约源，禁修），逐屏比对 Phase 3 落地视图。

### L2-A Dashboard ↔ AgentMockDashboardView

| 元素 | 预期 |
|---|---|
| AgentHeroCard | 深色渐变 ink → #273843；右上 yellow.opacity 0.34 blur 12 装饰圆；Iowan Old Style 68pt active 计数；3 mini stats (failed/stale/done) |
| FilterStrip | chips: All / Needs attention / Running / Blocked / Done；选中 ink 填充；未选中 paperHot 0.72 |
| AgentTaskCard | 2 列固定 LazyVGrid；paperHot 圆角 24；左侧状态色条 5pt；右上装饰圆 blur；avatar 首字母；Iowan 14pt heavy name + monospace 9pt task_id；ProgressView + updatedLabel + pin/mute icon |
| Demo push / Reconcile stale | Primary + Secondary capsule（注：**Demo push 当前为 stub**，无 PushArchiver 注入；L4 用例需要补 wiring） |
| History mini preview | Dashboard 底部 3 条 mini row |
| 空状态 | SetupHero 同款深色卡 + 跳 Setup CTA |

截图: `L2/dashboard-{15Pro}.png`、`L2/dashboard-empty.png`

### L2-B Detail ↔ AgentMockDetailView

| 元素 | 预期 |
|---|---|
| DetailHero | 深色渐变；StatusBadge → Iowan 36pt name + monospace task_id → 3 DetailMetric (progress/eta/updated) |
| Action row | Pin / Mute / Archive / Mark done（红色 tint） |
| SummaryPanel | 三态：ready (Summarize 按钮) / loading (3 行 SkeletonLine) / generated (≤3 句 + `cached · 5m`)；Phase 3 用 mock summary，Phase 6 接 LLM |
| StepRow | 左 monospace 42pt 时间列 + 右内容；paperHot 圆角 22 卡；StatusBadge + 14pt heavy title + 12pt medium body |
| Nav | `Agent detail` inline title |

截图: `L2/detail-{ready,loading,generated}.png`

### L2-C Setup ↔ AgentMockSetupView

| 元素 | 预期 |
|---|---|
| SetupHero | 深色卡 + `first push` Pill(dark) + Iowan 36pt 主标题 + 中英副文案 |
| curl 模板卡 | ink 黑底 + #EAF0E9 monospace 11pt；Copy curl / Send demo push 双按钮 |
| FieldExplainer | 4 行：group / task_id / agent_status / progress |
| 旧 Bark 兼容说明 | 引用 phase2-schema-migration §1.1 方案 C |

截图: `L2/setup.png`

### L2-D History ↔ AgentMockHistoryView

| 元素 | 预期 |
|---|---|
| HistoryHero | 深色卡 + `timeline` Pill + Iowan 34pt 标题 |
| 过滤 chip | All / Archived agents / Incoming / Memos |
| HistoryRow | paperHot 卡：title heavy + body secondary + kind Pill |
| Memo `+` | 顶部按钮（不在 Dashboard）|

截图: `L2/history-{all,memos,archived}.png`

### L2-E Search ↔ AgentMockSearchView

| 元素 | 预期 |
|---|---|
| 搜索框 | MockSearchFieldStyle: paperHot 圆角 21 + ink 12% 描边 + y=7 阴影 |
| scope chips | All / Agents / Steps / Memos (ChipButtonStyle) |
| filter pills | `status: ...` / `server: ...` / `last 7d`（Phase 3 占位） |
| 结果行 | kind Pill + 高亮命中 + 右侧 StatusBadge |

截图: `L2/search-empty.png`、`L2/search-query.png`

### L2-F Settings ↔ AgentMockSettingsView

| 元素 | 预期 |
|---|---|
| Servers section | SettingRow + Pill badge（online/offline 文案 Phase 4 接） |
| Agent behavior | Stale timeout 30m / On-device summary / Time Sensitive / Privacy |
| LiveActivityMockCard | V1.1 概念预告（waiting_input 状态 + 进度） |

截图: `L2/settings.png`

### L2-G 字体降级

- 切换 Simulator 语言为简体中文 → Iowan Old Style fallback 到 `.system(.largeTitle, design: .serif)`
- 截图 `L2/font-fallback-zh.png` 对照 `L2/font-en.png`

---

## L3 · DesignSystem 高风险组件矩阵（精简版）

> 仅覆盖高风险组件（hero / 卡片 / step / curl 黑底），其余组件随 L2 视觉走查覆盖。

| 组件 | 维度 | 用例数 |
|---|---|---|
| AgentHeroCard | 计数 0 / 1 / 99+ × 亮暗模式 | 6 |
| AgentTaskCard | 5 status × pin/mute 4 组合 × 长 name 截断 | 6 |
| DetailHero | 5 status × progress (无/3/7/45%/100%) × ETA 缺省 | 6 |
| SummaryPanel | ready / loading / generated × 短/长文本 | 6 |
| StepRow | 5 status × 单行/多行 body × 时间宽度 | 6 |
| curl 模板卡（Setup） | 短/长 URL × 浅暗模式 | 4 |

截图归档 `L3/{component}-{case}.png`

---

## L4 · 数据层与业务逻辑（受限 — 见缺口说明）

### L4 当前限制（must read）

- `AgentDashboardView.swift:124` "Demo push" 按钮为 **stub**（注释 `// Phase 4 接 mock 注入`），**当前无法点击触发 PushArchiver**。
- `PushArchiver` 已通过 `PendingQueueDrainer` 在 App 内可达（`App/Sources/PendingQueueDrainer.swift:26`），但无 UI 注入入口。
- ⏳ NSE 真实推送未实现 → 无法走 device token → APNs → NSE → archive 全链路。

→ L4 用例的执行需要二选一：

**A. 等 Demo push 按钮 wiring 完成**（建议：先加一个临时 dev-only 注入按钮）
**B. 单测代替**：跑 `PushArchiverTests`（已 63/63 绿），手动确认下列断言已被覆盖：

| 业务行为 | 已存在的单测 |
|---|---|
| 同 agent_id + task_id 聚合 | `PushArchiverTests.testAgentPushAggregatesByAgentAndTaskID` |
| 旧协议（无 agent_status）落 incoming Memo | `PushArchiverTests.testOldProtocolPushArchivesIncomingMemoByID` |
| 5 status 状态机 | `AgentRouterTests` / `PushParserTests` |
| `progress` 双格式 `3/7` 与 `45%` | `PushParserTests` |

### L4 推荐用例（A 路径生效后补做）

| 用例 | 步骤 | 预期 |
|---|---|---|
| L4-1 聚合 | Demo push 触发 3 次（同 agent_id+task_id）| Dashboard 1 张卡片 / Detail 3 条 step |
| L4-2 旧协议 | Demo push 触发不带 `agent_status` | Dashboard 不增卡 / History 新增 incoming Memo |
| L4-3 状态机 | 注入 5 status payload | StatusBadge 颜色与 mock 一致；排序优先级 waitingInput(1) < blocked(2) < failed(3) < running(4) < stale(5) < done(6) |
| L4-4 progress 渲染 | 注入 `progress=3/7` 与 `progress=45%` | 分别显示 `3/7` 与 `45%` |
| L4-5 stale 触发 | 构造 `updatedAt = now - 31min` 的 running task，点 Reconcile stale | status 变 stale，卡片灰化 |
| L4-6 mute/pin/archive/markDone | Dashboard 长按 → context menu | 状态变更后立即落库（杀进程重启验证） |
| L4-7 History 混合源 | 创建 1 Memo + 归档 1 AgentTask | History tab 联合呈现，按 updatedAt 排序 |

---

## L5 · 自动化测试复跑（每次手动测试前必做）

见 §1 前置自动化基线。

---

## L6 · 已知缺口与跳过项（明确登记）

| 缺口 | 关联任务 | 影响 | 处理 |
|---|---|---|---|
| 真实 APNs 注册 | 2.1 / 2.2 | 无法跑真机 E2E | 跳过；备注 "待 Phase 4.0 onboarding 接入后回归" |
| NSE 推送入口 | 2.3 | 无法验 Extension 内存 < 24MB | 跳过；改用 `PushArchiver` 直注入 |
| 解密推送 | 2.4 | 加密 payload 端到端不可测 | 跳过；单测覆盖 PushParser |
| Darwin Notification | 2.9 / 2.13 | NSE→主应用 < 500ms 刷新无法测 | 跳过；仅验主进程 upsert |
| EnrichProcessor / PresentProcessor | 2.10 / 2.11 | 通知图片/图标/UN content 未实现 | 跳过 |
| PendingQueue 扩展类型 | 2.12 | LA / archiveStep type 未实现 | 跳过 |
| Setup tab curl 模板真实注入 | Phase 4.13 | 当前为硬编码 | L2-C 仅验视觉，不验数据 |

---

## 7. 退出标准

- L0 全部通过（任一阻断）
- L1 / L2 / L3 截图归档完整，与 mock diff 经 review
- L5 自动化绿
- L4 通过 A 路径或 B 路径有明确签字
- L6 缺口在 report 中逐条标注 "本轮跳过 / 计划阶段"

## 8. Report 模板

见 `doc/phase2-manual-test-report.md`。
