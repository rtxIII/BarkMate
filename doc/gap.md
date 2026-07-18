# 进度功能 Gap 分析

> 范围：Agent 进度（progress）从推送解析到 Dashboard 渲染的完整链路。
> 结论：主解析逻辑（happy path）已被 E2E 验证；曾存在 2 个渲染问题 + 1 个遗留死代码 + 1 个测试盲区 + 1 个产品真实性问题。
> 状态：P1 / P2 / P3 / F1 已修复（2026-07-16）；P5 待补 E2E。
> 日期：2026-07-16

## 链路概览

```
Bark 推送 (progress 可选, "3/7" 或 "65%")
  → PushParser.progress: String?            解析原始字符串
  → PushArchiver                            upsert 到 AgentTask.progress / AgentStep.progress
  → AgentCardData.progressFraction(from:)   String → Double? (两种格式都覆盖)
  → 渲染:
      · MCRunCompactRow   Running / Settled 段唯一进度条组件（MCProgressBar）
      · MCAttentionCard   Needs-you / failed 卡，只显 progressLabel 文本，无条
      · DetailHero        detail 页只显 progressLabel 文本，无条
```

实况 Dashboard 仅用 `MCRunCompactRow` / `MCAttentionCard`（曾并存的 `AgentTaskCard` 已作死代码删除，见 P3）。

## 已验证问题

### P1（最可能，高频命中）— 运行中但无 progress 字段 → 空进度条 + 空百分比 ✅ 已修复

- `progress` 在推送里可选，`PushParser` 缺省返回 `nil`；大量只带 `title`/`body` 的普通推送都没有它。
- `MCRunCompactRow.swift:54` 固定画 90pt 条：`MCProgressBar(value: data.progressFraction ?? 0)` → `nil` 渲染成 **0% 空条**。
- `MCRunCompactRow.swift:88` `pctLabel`：`status != done` 且 fraction 为 nil → 落到 `progressLabel ?? ""` → **空字符串**。
- 现象：正常在跑的 agent，视觉上像"卡在 0% / 死掉"。
- 对照：`MCAttentionCard` 是"没进度就不画"，此处却强制画空条 → 不一致。
- **修复**：`MCRunCompactRow` 引入 `effectiveFraction = isDone ? 1 : progressFraction`；为 `nil` 时用 `if let` 隐藏进度条列 + 百分比列，不再画空条。

### P2（真实，**高频** — 手动 Mark Done 必现）— done 状态但进度条不满 ✅ 已修复

- **主触发源（验证补记）**：`AgentDashboardView.swift:396` 与 `AgentDetailView.swift:186` 的 `markDone` **只设 `task.status = .done`，完全不动 `progress`**。用户对任一 `progress=3/6` 的 running 卡点「Mark Done」立即触发，属必现高频，而非边界。
- 次触发源：`PushArchiver.swift:68` `existing.progress = parsed.progress ?? existing.progress`，完成推送不带 progress 时保留旧值（如 `3/7`）。
- 旧渲染：条 = `progressFraction ?? 0` = 0.43，但 `pctLabel` 因 `status == .done` 显示 `"DONE"` → **lime 条只填 43%，右侧写 DONE**；与视觉契约 `.r-row.done`（满条）冲突。全程未报 progress 则 "空条 + DONE"。
- **修复**：`MCRunCompactRow` render 层 `isDone ? 1 : progressFraction` 强制 done 满条，一处覆盖手动 + 推送两个触发源（done accent 已是 lime）。未改数据层，避免分散且能救「done 从未带 progress」的情况。

## 次要 / 遗留（真实但非 live）

### P3 — AgentTaskCard 仍用原生 ProgressView ✅ 已删除

- 原 `AgentTaskCard.swift:77` `ProgressView(...)`（圆角胶囊），与 `MCProgressBar` 文档"就是为替代它（锐角风冲突）"的契约相悖。
- 验证：全仓 `AgentTaskCard(` 仅出现在其自身 `#Preview` 中，**classic 与 missionControl 两个变体均无 live 调用**，整组件为死代码。
- **处置**：整文件 `AgentTaskCard.swift` 已删除（无外部引用，`MockScreenBackground` 等依赖别处仍在用，无孤儿）。

### P4 — detail 页无进度条

- `DetailHero` / `AgentDetailView.swift:134` 只展示 `progressLabel` 文本 → **设计如此，非 bug**。

### P5（测试盲区，已降级）— `%` 百分比格式有单元测试、缺 E2E

- **修正**：`%` 解析**已有单元测试** —— `DashboardMappingTests.swift:43` 断言 `"75%"→0.75`、`:44` `"125%"→1.0`。故非"零覆盖"。
- 缺口仅在 E2E：§5.4 只发 `1/3` 分数格式，`%` 分支无端到端验证。
- 属测试覆盖缺口（低价值），非渲染 bug。

## 与模拟器 E2E 的对照

对照 `doc/app-automated-test-guide.md` §5.4「执行阶段」的进度相关用例：

| E2E 步 | 动作 | 断言 | 对 gap 的影响 |
|---|---|---|---|
| 2 | `progress=1/3` running | `33%` | 验证了 fraction→bar→pctLabel 的 **happy path**（`Int(1/3*100)=33`） |
| 3 | `progress=2/3` waiting_input | 进 Needs You / WAIT | 验证 waiting 态文本 |
| 4 | `progress=3/3` done | 进 Settled | done 恰好带 `3/3`（=满条），**绕开 P2** |
| 9 | 加密成功 | Dashboard `50%` | 验证解密后进度渲染 |

**结论：E2E 的进度用例全部走 happy path、每条都显式带 progress。** 由此：

- **P1**（running 无 progress → 空条）：E2E 从不发"缺 progress"的 running 推送 → **该路径 E2E 未跑过**，P1 不是理论推测而是确认的测试盲区。
- **P2**（done 但条不满）：step 4 的 done 带 `3/3`=1.0 满条，刚好避开；真实中"done 不带 progress → 保留旧值"E2E **同样未覆盖**。
- **P5**：E2E 只用分数格式，`%` 分支缺 E2E（但有单元测试，见 P5）。

反向印证正确面：step 2 断言 `33%` 说明 happy path 的解析与渲染是被 E2E 验证过的，问题仅在 nil / stale / `%` 边界。

> 交叉引用：`doc/app-automated-test-guide.md` §9「未覆盖场景」已补 running/done 缺 progress 字段与 `%` 格式两条对应缺口。

## 相关发现（非进度链路）

### F1 — Settings「Hooks」段 `active` 徽标为硬编码 ✅ 已修复

- 原 `SettingsView.swift:88` `MCSettingStateBadge("active", color: .lime)` 恒显 "active"，**不反映 hook 是否真的已安装**。
- 约束：hook 装在用户开发机（curl 脚本），iOS app 无法直接探测，故无法精确"如实反映"。
- **修复（弱代理信号）**：SettingsView 新增 `@Query [AgentTask]`；以"是否收到过 ≥1 条 agent 推送"（`!agentTasks.isEmpty`）为设备端可靠间接证据 —— 收到过 → `active`（lime）；从未 → `setup`（inkSoft）+ 引导文案。
- 关联测试侧记录：`doc/app-automated-test-guide.md` §9「Hooks 段展示内容」。

## 已排除的假设（可追溯）

| 疑点 | 结论 |
|---|---|
| 解析函数只支持一种格式 | 证伪：`3/7` 与 `65%` 均覆盖（`AgentDashboardView.swift:468`） |
| MCProgressBar clamp 越界 | 证伪：已 `max(0, min(1, value))`（`MCProgressBar.swift:25`） |
| detail 页缺进度条是 bug | 证伪：设计如此（P4） |

## 已实施的修法

1. **P1**（`MCRunCompactRow.swift`）：`effectiveFraction = isDone ? 1 : progressFraction`；为 `nil` 时以 `if let` 隐藏进度条列 + 百分比列，不再画 0% 空条。
2. **P2**（同上一处）：done 态强制满条，一处 render 同时覆盖手动 `markDone` 与不带 progress 的完成推送两个触发源。`pctLabel` 改为接收非空 fraction。
3. **P3**：删除死代码 `AgentTaskCard.swift`（整文件）。
4. **F1**（`SettingsView.swift`）：Hooks 徽标改弱代理信号，`@Query [AgentTask]` + `!isEmpty` 判定 `active` / `setup`。

## 状态

- [x] P1 修复（`MCRunCompactRow`）
- [x] P2 修复（`MCRunCompactRow`，覆盖 markDone + 推送）
- [x] P3 删除死代码（`AgentTaskCard.swift`）
- [x] F1 弱代理信号（`SettingsView` Hooks 徽标）
- [ ] P5 补 E2E：running/done 缺 progress、`%` 格式（低优先）
- [x] 构建 / 测试验证：DesignSystem `swift build` ✅ / App target `xcodebuild build`（含 NSE + Widgets）BUILD SUCCEEDED ✅ / `BarkMateTests` 15 passed·0 failed（3 加密夹具按设计 skipped）✅
- [x] 更新截图回归基线：7 张基线重录（`TEST_RUNNER_BARKAGENT_RECORD_SCREENSHOTS=1`）；不带 record 复跑比对 3/3 passed ✅

> 备注：手册 §4.5 的 `BARKAGENT_RECORD_SCREENSHOTS=1 xcodebuild` 不会注入到模拟器 UI runner 进程，实际录不进基线；需用 `TEST_RUNNER_` 前缀让 Xcode 剥前缀后注入 runner。
