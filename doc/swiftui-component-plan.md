# SwiftUI 组件清单 — Mission Control 落地路径

> 视觉契约：`doc/mock/screens-b-missioncontrol.html`
> Design tokens：`Packages/DesignSystem/Sources/DesignSystem/Tokens/MissionControl*`
> 现有组件库：`Packages/DesignSystem/Sources/DesignSystem/*.swift`（21 个 View / 数据结构）

本清单的目的：**让 SwiftUI 实现的下一步可以照表施工**，不再回头查 mock HTML 或现有 Swift API。

---

## 0. 总体原则

| 决策 | 内容 |
|---|---|
| **不动 BarkTheme** | 旧暖纸杂志风组件全部保留，避免污染。Mission Control 走并列命名空间 |
| **三类组件** | ✅ 复用：现有组件够用 / ⚠️ 改造：加 MC style 变体 / 🆕 新增：现有完全没有 |
| **改造命名** | 现有组件不改 init 签名。新增 `func.missionControlStyle()` view modifier，或新增 `init(... style: .missionControl)` |
| **ViewModel 复用** | `AgentCardData / StepRowData / HistoryItemData / DetailHeroData / AgentHeroCounts / SummaryPanelState` 不变 |
| **新增 ViewModel** | 仅当 mock 有新概念时（如 `TriagePanelData / RunCompactRowData / LockCardData`） |
| **字体注册** | `BarkMateApp.init()` 调用一次 `MissionControl.Font.register()` |
| **App 背景** | 整个 App 根视图加 `MissionControl.Color.background.ignoresSafeArea()` |

---

## 1. 全局基础设施（Foundation）

| # | 文件 / 组件 | 类型 | 工作量 | 说明 |
|---|---|---|---|---|
| F1 | `BarkMateApp.swift` | ⚠️ 改造 | XS | `init()` 加 `MissionControl.Font.register()` |
| F2 | `MainTabView.swift` | ⚠️ 改造 | S | `.tint(MissionControl.Color.accent)`；删除 `.setup` tab；改顺序为 Agents / History / Search / Settings；`AppTab` 同步去掉 `.setup` 枚举值 |
| F3 | `MCBackground` | 🆕 新增 | S | View modifier `.mcScreenBackground()`，给所有屏幕提供 void + 32px 栅格 mask + 横扫描线（mock HTML body::before/after 翻译） |
| F4 | `MCConsoleHeader` | 🆕 新增 | M | App bar：左 crumbs（SYS / OPS / DOSSIER 等）+ 中 title（Inter Tight 30pt + Instrument Serif italic 强调）+ 右 icon button |
| F5 | `MCTabBar` | 🆕 新增 | M | 替换系统 TabView 外观，做成栅格分段控件（4 列等宽 + amber active）。**实现路径**：用 `TabView` + 自定义 `UITabBarAppearance`（iOS）或直接用 HStack 自绘 + `Selection` binding。**推荐**：自绘，避免 system tabbar 限制 |
| F6 | `MCSectionHeader` | 🆕 新增 | XS | `▸ NEEDS YOU  /  02 cards`：左侧前缀 amber 三角 + 右侧 metadata。替代旧 `SectionTitle` 在 MC 上下文中的位置 |
| F7 | `MCIconButton` | 🆕 新增 | XS | 32×32 方形描边按钮（hover/press amber 反相），替换 `Image(systemName:)` 在 console header 的用法 |

---

## 2. 状态徽章与小元素（Atoms）

| # | 现有 / 新文件 | 类型 | 工作量 | 说明 |
|---|---|---|---|---|
| A1 | `StatusBadge.swift` | ⚠️ 改造 | S | 新增 `init(status:, style: .missionControl)`。MC 风用 `status.mcCode`（`[ WAIT ]`）+ `status.mcColor` + 方角矩形 + 1pt 描边。**保留** compact 圆点圆角风供旧组件用 |
| A2 | `Pill.swift` | ⚠️ 改造 | XS | 新增 `func mcPill()` modifier，给 Pill 文字加 MC bodyMono 字 + 锐角 + ruleHot 描边。**保留** 旧暖纸 Pill |
| A3 | `AgentAvatar.swift` | ⚠️ 改造 | XS | 新增 MC 变体：2 字母首字母 + JetBrainsMono Bold + cyan 文字 + 透明背景（mock B 里 `.r-row .av` 就是无背景纯字符） |
| A4 | `MCBracketBadge` | 🆕 新增 | XS | 极简版本：纯文字 `[ WAIT ]` + 1pt 边框，给行内紧凑使用。和 A1 区别：A1 带背景 fill + 高亮，A4 只是描边方框 |
| A5 | `MCProgressBar` | 🆕 新增 | S | 4pt 高、纯矩形、`rule` 底 + `status.mcColor` 填充 + `status.mcGlow` shadow。替换 SwiftUI 原生 `ProgressView()` |
| A6 | `MCChip` | 🆕 新增 | XS | filter chip：锐角矩形 + ruleHot 描边 + active 反白（ink 底 + void 字）。mock 中 `Search` / `History` 用 |
| A7 | `MCToggle` | 🆕 新增 | XS | 锐角矩形 toggle（22×44）+ amber on 态。**不要用系统 Toggle**（圆胶囊形与 MC 风格冲突） |

---

## 3. 卡片与列表行（Molecules）

| # | 现有 / 新文件 | 类型 | 工作量 | 说明 |
|---|---|---|---|---|
| C1 | `AgentTaskCard.swift` | ⚠️ 改造 | M | 新增 `init(data:, style: .missionControl)`。MC 风：`hull` 背景 + 锐角 + 4pt 左色条（marker 用 `status.mcColor`）+ amber 描边（needsAttention 时）+ Inter Tight 17pt 标题 + JetBrains Mono 10pt code line。**保留** 旧 paperHot 风 |
| C2 | `MCAttentionCard` | 🆕 新增 | M | "Needs you" 大卡专用变体，比 C1 多两个元素：`» ask 引文区`（左 2pt rule 边 + amber `»` 前缀）+ 底部 metadata 行。**实现路径**：可以直接是 C1 的 MC style 子集 + 一个 `askBody` 参数 |
| C3 | `MCRunCompactRow` | 🆕 新增 | M | "Running" / "Settled" 紧凑行，4 列网格：`28pt avatar` `1fr body(标题+副)` `90pt 进度条` `auto pct`。每行底部 `rule` 1pt 分隔线。需要新 VM `RunCompactRowData` |
| C4 | `StepRow.swift` | ⚠️ 改造 | M | 新增 `init(data:, style: .missionControl)`。MC 风：去掉卡片包裹，改为列式布局：56pt time（amber JetBrainsMono + 36pt rule 短线）+ 1fr (badge + Inter Tight 13.5pt 标题 + JetBrainsMono 11pt body)。底部 1pt `rule` 分隔 |
| C5 | `HistoryRow.swift` + `HistoryMiniRow.swift` | ⚠️ 改造 | S | 加 `.missionControlStyle()` modifier：`hull` 背景、锐角、Inter Tight 标题、`amber` time + `inkSoft` 小写 metadata 分行显示。**保留** 旧 `mockCardPadding()` 风 |
| C6 | `MCResultRow` | 🆕 新增 | S | Search 结果行：56pt kind 三字母前缀（`AGT` / `STP` / `MEM` 各自配色 magenta/cyan/lime）+ 1fr 标题与高亮 body（`amber` 高亮 hit 段）+ auto time。复用 `HistoryItemKind` 枚举但**加字段 `summary: AttributedString`** 用来塞高亮 |
| C7 | `MCSettingRow` | 🆕 新增 | S | 与现有 `SettingRows.swift` 并列。Mock B Settings 每行：左 `Inter Tight 13pt 标题 + JetBrainsMono 10.5pt 副文` / 右 `value` 或 `MCToggle` 或 `MCBracketBadge`。改造 `SettingRows.swift` 加 MC style 也行，差别看现有 API 而定 |

---

## 4. 大型复合区块（Organisms）

| # | 现有 / 新文件 | 类型 | 工作量 | 说明 |
|---|---|---|---|---|
| O1 | `AgentHeroCard.swift` | ⚠️ 重写 MC 变体 | L | 当前是单卡圆角 + 67pt 大数字。MC 版叫 `MCHeadsUpPanel`：外层 1pt rule + hull 底；顶部 `— HEADS-UP / 06 AGENTS — ● LIVE`；下方三栏 triage（用 `MissionControl.Status.Bucket` 已建好的桶）。**推荐**：保留旧 `AgentHeroCard` 不动，新建独立文件 `MCHeadsUpPanel.swift`，因为结构差异太大不适合复用 |
| O2 | `MCTriageCell` | 🆕 新增 | S | O1 内部 3 个 cell 之一：`hullDeep` 底 + 1pt rule + amber/cyan/inkMute 大数字（Inter Tight 44pt Black）+ JetBrainsMono uppercase 标签 + 副标题。`needsYou` cell 额外加 amber 描边 + 内 glow |
| O3 | `DetailHero.swift` | ⚠️ 重写 MC 变体 | L | 当前是深底渐变 hero 圆角 30。MC 版叫 `MCDossierHero`：amber 1pt 描边 + 四角 L 形 2pt 角标（用 `Path` 画 4 个 L）+ Inter Tight 32pt agent 名 + Instrument Serif italic 子串 + 3 个 metric tile。**新建独立文件**，原 DetailHero 保留 |
| O4 | `SummaryPanel.swift` | ⚠️ 改造 | S | 加 MC style：1pt dashed border（用 `StrokeStyle(lineWidth: 1, dash: [4])`）+ hull 底 + `[ on-device summary · cached ]` lime 小标签 + JetBrainsMono 11pt body + 12pt 行高。**保留**原 ready/loading/generated 三态逻辑 |
| O5 | `FilterStrip.swift` | ⚠️ 改造 | XS | 加 MC style：用 A6 MCChip 替换内部 chip 样式。**保留** binding API |
| O6 | `EmptyDashboardState.swift` | ⚠️ 改造 | S | MC 版用 `void` 底 + `inkSoft` 文案 + `MCButton` 主操作。简单调色 |
| O7 | `NotificationStatusBanner.swift` | ⚠️ 改造 | S | 改色板映射到 MC：`authorizationDenied→amber`, `apnsRegistrationFailed→orange`, `serverUnreachable→magenta`, `storageUnavailable→magenta`。同时锐角 + 1pt 描边版本。**保留**旧暖纸风 |

---

## 5. 屏级容器（Pages — 全部走 ⚠️ 重写）

> 屏级页面都在 `BarkMate/App/Sources/Views/` 下。改的是 layout 和组件选择，不改 ViewModel 与数据流。

### P1. `AgentDashboardView.swift` — Today / Triage

**Mock 对应**：screens-b-missioncontrol.html §02

**布局拆解**：
```
MCScreenBackground
└── ScrollView
    ├── MCConsoleHeader(crumbs: ["OPS", "TODAY", "MON · 0615"], title: "Today.", trailing: MCIconButton("⌁"))
    ├── MCHeadsUpPanel(counts: AgentHeroCounts)               [O1]
    │   └── HStack: MCTriageCell × 3                          [O2]
    ├── MCSectionHeader("Needs you", trailing: "02 cards")    [F6]
    ├── ForEach(needsYouAgents):  MCAttentionCard(data:)      [C2]
    ├── MCSectionHeader("Running", trailing: "03 agents")
    ├── ForEach(runningAgents):   MCRunCompactRow(data:)      [C3]
    ├── MCSectionHeader("Settled", trailing: "01")
    └── ForEach(settledAgents):   MCRunCompactRow(data:)      [C3 · done variant]
```

**数据流**：现有 `AgentDashboardView` 的 SwiftData query + filter 逻辑全部保留。`AgentHeroCounts` 不变。新增一个 `bucketedAgents: [Bucket: [AgentCardData]]` 计算属性，按 `AgentStatus.mcBucket` 分组。

**底部**：`MCTabBar` 取代系统 TabView（如果走 F5 自绘路线）。

---

### P2. `AgentDetailView.swift` — Dossier

**Mock 对应**：§03

**布局拆解**：
```
MCScreenBackground
└── ScrollView
    ├── MCConsoleHeader(crumbs: ["OPS", "DOSSIER", "TASK-0420"], title: "Dossier", trailing: MCIconButton("···"))
    ├── MCDossierHero(data: DetailHeroData)                   [O3]
    ├── SummaryPanel(state:).missionControlStyle()            [O4]
    ├── HStack: MCButton × 4 (Pin / Mute / Archive / Done)    [新 ghost 4 列]
    ├── MCSectionHeader("Step log", trailing: "03 pushes")
    └── ForEach(steps): StepRow(data:, style: .missionControl) [C4]
```

**操作按钮**：mock 是 `Pin / Mute / Archive / Done`，前 3 个 ghost、Done 实心 amber。不在范围内的 reply 不画。

---

### P3. `HistoryView.swift` — Archive & memos

**Mock 对应**：§04

**布局拆解**：
```
MCScreenBackground
└── ScrollView
    ├── MCConsoleHeader(crumbs: ["SYS", "HISTORY", "JUN · 2026"], title: "History", trailing: MCIconButton("+"))
    ├── MCBanner(title: "Messages become context, not noise.", subtitle: "— OPS NOTE / 0615 —")   [新简单组件,渐变橙底]
    ├── HStack: MCChip × 4 (All / Archived / Incoming / Memos) [A6]
    ├── MCSectionHeader("Today", trailing: "02 items")
    ├── ForEach(todayItems):    HistoryRow(data:).missionControlStyle()  [C5]
    ├── MCSectionHeader("Earlier · Jun 14", trailing: "02 items")
    └── ForEach(earlierItems):  HistoryRow(data:).missionControlStyle()
```

**新增**：`MCBanner` 一个简单组件（amber→orange linear gradient + 装饰圆 + void 文字）。工作量 XS。

---

### P4. `SearchView.swift` — Lookup

**Mock 对应**：§05

**布局拆解**：
```
MCScreenBackground
└── ScrollView
    ├── MCConsoleHeader(crumbs: ["SYS", "SEARCH", "q · \"mock\""], title: "Search", trailing: MCIconButton("⌘"))
    ├── MCSearchInput(text: $query)                           [新组件: amber 左竖条 + amber › 前缀 + 闪烁 caret + Clear 按钮]
    ├── HStack: MCChip × 4 (All / Agents / Steps / Memos)
    ├── Text("— 04 hits · last 7 days · sorted by relevance —") [JetBrainsMono 9.5pt amber/inkSoft 混合]
    └── ForEach(results):  MCResultRow(data:)                  [C6]
```

**新增**：`MCSearchInput`（XS-S）。现有 `MockSearchFieldStyle.swift` 可参考但风格不一致，建议新写。

---

### P5. `SettingsView.swift` — Tactical Settings

**Mock 对应**：§06

**布局拆解**：
```
MCScreenBackground
└── ScrollView
    ├── MCConsoleHeader(crumbs: ["SYS", "SETTINGS"], title: "Settings", trailing: MCIconButton("+"))
    ├── MCSectionHeader("Servers", trailing: "02 online")
    ├── ForEach(servers):   MCSettingRow(...)                  [C7]
    ├── MCSectionHeader("Agent behavior", trailing: "defaults")
    ├── MCSettingRow("Stale timeout", value: "30 min")
    ├── MCSettingRow("On-device summary", trailing: MCToggle(isOn:))
    ├── MCSettingRow("Time-Sensitive alerts", trailing: MCToggle(isOn:))
    ├── MCSectionHeader("Privacy", trailing: "local")
    ├── MCSettingRow("Analytics", value: "off")
    └── MCSettingRow("Setup guide", value: "open ›", navigates: SetupView())
```

**Setup 入口**：放在 Privacy 段下面，链接进入 `SetupView`（保留现有 SetupView 文件，只是从 tab 改成子页）。

---

### P6. `SetupView.swift` — Onboarding（保留为 Settings 子页）

**Mock 对应**：§01

**改造**：现有 SetupView 加 MC style 外壳；内容（curl block / 字段表）保留，调成 MC 颜色与字体。

**布局拆解**：
```
MCScreenBackground
└── ScrollView
    ├── MCConsoleHeader(crumbs: ["SYS", "SETUP", "0001"], title: "First push", trailing: MCIconButton("?"))
    ├── MCSetupHero(title: "One push.\nOne living card.", lead: "...")  [新简单组件]
    ├── MCCodeBlock(code: "curl -X POST ...")                  [新: 1pt rule + 3pt amber 左条 + $ shell 角标 + JetBrainsMono 10pt]
    ├── HStack: MCButton × 2 (Copy curl / Send demo)
    └── MCFieldKey(entries: [(group, "..."), (task_id, "..."), ...])  [新: 110pt cyan key + 1fr inkSoft value · dashed 分隔]
```

**新增 3 个小组件**（都是 XS-S 工作量）：`MCSetupHero` / `MCCodeBlock` / `MCFieldKey`。

---

### P7. Live Activity（v1.1，先不实现）

**Mock 对应**：§07

**实现路径**：iOS ActivityKit + Lock Screen / Dynamic Island。**当前阶段不动**，token 已经留好（`MissionControl.Color.amber/amberGlow` + Family.display + Family.serifItalic），等 Phase 6 / v1.1 再开工。

---

## 6. 工作量汇总

| 阶段 | 内容 | 工作量估计 |
|---|---|---|
| **Foundation（F1-F7）** | 字体注册 + Tab 改造 + 背景 + Header + TabBar + IconButton + SectionHeader | ~1.5 天 |
| **Atoms（A1-A7）** | 状态徽章 / Pill / Avatar / BracketBadge / ProgressBar / Chip / Toggle | ~1 天 |
| **Molecules（C1-C7）** | TaskCard MC 变体 + AttentionCard + RunCompactRow + StepRow MC + HistoryRow MC + ResultRow + SettingRow | ~2 天 |
| **Organisms（O1-O7）** | HeadsUpPanel + TriageCell + DossierHero + SummaryPanel MC + FilterStrip MC + Empty MC + Banner MC | ~2 天 |
| **Pages（P1-P6）** | Dashboard / Detail / History / Search / Settings / Setup 五屏改造 | ~2 天 |
| **联调与回归** | mock 截图对比、暗黑模式适配、动态字号、VoiceOver | ~1 天 |
| **合计** | | **~9.5 天**（单人节奏） |

---

## 7. 落地顺序建议

按依赖关系，**自下而上**：

```
Day 1   F1+F2+F3              字体注册 / Tab 改造 / 背景 modifier
Day 2   F4+F5+F6+F7+A1+A2+A3  Header / TabBar / SectionHeader / IconButton / StatusBadge / Pill / Avatar
Day 3   A4-A7 + C4 + C5       BracketBadge / ProgressBar / Chip / Toggle + StepRow MC + HistoryRow MC
Day 4   C1+C2+C3+O2           AgentTaskCard MC + AttentionCard + RunCompactRow + TriageCell
Day 5   O1+P1                 HeadsUpPanel + AgentDashboardView 重写（首个屏完整跑通）
Day 6   O3+O4+P2              DossierHero + SummaryPanel MC + AgentDetailView 重写
Day 7   P3+P4+C6              HistoryView + SearchView + MCResultRow
Day 8   P5+P6+C7+小组件        SettingsView + SetupView + SettingRow + MCBanner/SetupHero/CodeBlock/FieldKey
Day 9   联调 / 截图对比 / 回归   暗黑模式 / 动态字号 / VoiceOver
```

**关键检查点**：
- Day 2 末：跑一个空 `Tabs` + `Header` 的 shell，验证字体注册成功（看 console 是否打印 fallback）
- Day 5 末：第一个完整屏（Dashboard）能开始截图对比 mock B §02
- Day 8 末：6 屏全部能跑通

---

## 8. 与 Phase 当前状态的关系

PRD `phase2-schema-migration.md` 已经冻结 `agent_status / task_id / progress / eta` 字段——本清单**不触发任何 schema 改动**。

PRD §18 写：
> 原型确认后，Phase 2 应冻结字段。**Dashboard 和 Detail 的交互应作为 Phase 3 的实现基线**。

本清单可以直接作为 Phase 3 的 UI 实现 spec，**不需要再补一份 design spec doc**。
