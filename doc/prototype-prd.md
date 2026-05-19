# BarkMate — 原型 PRD

> 版本：0.1.0  
> 日期：2026-05-15  
> 状态：Draft  
> 输入文档：`doc/product.md` v0.3.0、`doc/design.md` v0.3.0、`doc/plan.md` v0.3.0、`doc/bark-protocol.md`

## 1. 原型目标

BarkMate 原型用于验证一个核心判断：**AI Agent 的运行结果不应该以消息流呈现，而应该以持久状态卡片呈现。**

原型需要让评审者在 3 分钟内理解：

- 当前有哪些 agent / task 正在跑；
- 哪些 task 等待用户输入、阻塞、失败或已完成；
- 同一 task 的多次推送如何聚合成一张卡片；
- 点击卡片后如何看到原始 step 历史与进度摘要；
- 新用户如何从空状态复制 curl 模板完成首次接入。

本 PRD 面向**交互原型 / 高保真 UI 原型 / 可运行 Demo**，不是完整 V1.0 开发 PRD。

## 2. 背景与问题

AI Agent 常以终端、后台任务、CI pipeline、workflow 的形式长时间运行。用户离开电脑后会遇到三个问题：

- **状态不可见**：不知道 agent 是 running、waiting_input、blocked、done 还是 failed。
- **进度不可读**：多步任务只能通过日志判断进度，成本高。
- **消息流混乱**：传统 Bark / Telegram / Slack 推送是孤立消息，无法表达“同一个 task 的最新状态”。

BarkMate 的产品机会是把 Bark 推送协议升级为一个本地优先的 **Agent Dashboard**：仍然用 HTTP 推送接入，但客户端按 `agent_id + task_id` 聚合为状态卡片。

## 3. 原型成功标准

| 目标 | 验收标准 |
|---|---|
| 状态一眼可见 | 首屏能同时展示至少 6 张 active agent 卡片，并能区分 running / waiting_input / blocked / failed |
| 聚合语义清晰 | 同一 `agent_id + task_id` 的多条 step 在原型中只更新同一张卡片 |
| 详情可追溯 | 点击卡片后能看到当前状态、进度、摘要区域、step 时间线 |
| 接入路径明确 | 空状态页提供可复制 curl 示例，用户知道如何发第一条 agent 推送 |
| 范围可控 | 原型不强依赖真实 APNs、真实 Apple Intelligence、真实 Live Activity |

## 4. 目标用户

### 主要用户：并行运行 AI Agent 的开发者

典型行为：

- 同时运行 Claude Code、Codex、Cursor、Aider、自建 agent workflow；
- 会写 shell hook 或 HTTP webhook；
- 需要在手机上查看后台任务状态；
- 已经熟悉 Bark 或类似 push 工具。

### 次要用户：CI / 自动化重度用户

典型行为：

- 运行 GitHub Actions、GitLab CI、本地 cron、n8n workflow；
- 长任务包含 lint、build、test、deploy 等多个步骤；
- 需要一个比“通知历史”更结构化的状态视图。

## 5. 原型范围

### 原型内必须包含

- Onboarding / 空状态接入引导；
- Agent Dashboard 主屏；
- Active Agent 卡片网格；
- 全局状态摘要栏；
- History Timeline 预览区；
- Agent 详情页；
- Step 历史时间线；
- “总结进度”区域的 UI 表达；
- 状态过滤与搜索入口的视觉占位；
- 卡片长按 / 更多菜单：置顶、归档、静音、标记完成；
- 模拟推送数据：running、waiting_input、blocked、done、failed、stale。

### 原型内只做占位

- 设备端 LLM：展示模拟摘要，不接真实 FoundationModels；
- Live Activity：展示锁屏 / Dynamic Island 的概念画面，不做系统级实现；
- 多服务器：展示设置入口和服务器列表样式，不做真实注册；
- 加密配置：展示字段，不做真实 AES 配置流程；
- 搜索：展示搜索页和结果样式，可用 mock 数据。

### 原型外不包含

- 远程控制 agent；
- agent 编排 / DAG 视图；
- iCloud 同步；
- 账号系统 / 订阅；
- Android / iPad 专属布局；
- 完整 Markdown 备忘录编辑器；
- Share Extension；
- Siri / App Intents；
- 真实 APNs 注册和推送链路。

## 6. 核心概念

### 6.1 AgentTask

一张 Dashboard 卡片，对应同一个 `agent_id + task_id` 聚合。

核心字段：

| 字段 | 说明 |
|---|---|
| `agent_id` | agent 或任务来源，优先来自 Bark `group` |
| `task_id` | 单次任务 ID，可选；缺省时按 `agent_id` 聚合 |
| `status` | running / waiting_input / blocked / done / failed / stale |
| `latest_step_title` | 最新一步标题 |
| `progress` | `3/7`、`45%` 等字符串 |
| `eta` | 预计完成时间，可选 |
| `updated_at` | 最近一次推送时间 |

### 6.2 AgentStep

一条原始推送记录，归属于某个 AgentTask。详情页通过 step 时间线还原 task 历史。

### 6.3 Memo / History Item

旧 Bark 推送或用户备忘录，不进入 Active Agent 卡片网格，进入 History Timeline。

## 7. 状态规则

| 状态 | 含义 | 视觉表达 |
|---|---|---|
| running | 正在执行 | 蓝色状态徽章，卡片保持活跃 |
| waiting_input | 等待用户输入 | 黄色徽章，突出“需要处理” |
| blocked | 因资源、token、依赖等卡住 | 橙色徽章，卡片高优先级 |
| done | 成功完成 | 绿色徽章，可归档 |
| failed | 失败终止 | 红色徽章，卡片高优先级 |
| stale | 运行中但超过阈值无更新 | 灰色徽章，弱化但提醒可能已死 |

原型规则：

- `running` 超过 30 分钟无更新显示为 `stale`；
- `waiting_input`、`blocked`、`failed` 在排序上优先于普通 `running`；
- `done` 默认仍可短暂出现在 Dashboard，也可进入 History；
- 客户端不校验状态转换合法性，agent 推送是事实来源。

## 8. 信息架构

```text
BarkMate Prototype
├── Onboarding / Empty State
│   ├── 产品概念说明
│   ├── 默认服务器说明
│   └── curl 接入示例
├── Dashboard
│   ├── 全局状态摘要栏
│   ├── Active Agents 卡片网格
│   ├── 状态 / agent / server 过滤入口
│   └── History Timeline
├── Agent Detail
│   ├── 当前状态头部
│   ├── 进度与 ETA
│   ├── 进度摘要区域
│   ├── Step 历史时间线
│   └── 操作菜单
├── Search
│   ├── 搜索框
│   ├── scope chips
│   └── agent / step / memo 混合结果
└── Settings Preview
    ├── Server list
    ├── Notification preferences
    ├── Stale threshold
    └── Privacy note
```

## 9. 关键用户流程

### 9.1 首次启动并接入 agent

1. 用户打开 BarkMate。
2. 看到空 Dashboard 和一句定位：`Your pocket dashboard for long-running AI agents.`
3. 页面展示默认服务器与设备 key 的概念。
4. 用户点击 `Copy curl example`。
5. 复制内容示例：

```bash
curl -X POST "https://api.day.app/<key>" \
  -d "group=backend-refactor" \
  -d "task_id=auth-migration-0420" \
  -d "agent_status=running" \
  -d "progress=3/8" \
  -d "title=Refactoring auth middleware" \
  -d "body=Updated auth.ts, now fixing tests"
```

6. 原型模拟收到第一条推送，Dashboard 出现一张 running 卡片。

### 9.2 查看并行 agent 状态

1. 用户进入 Dashboard。
2. 顶部显示：`3 running · 1 waiting · 1 blocked`。
3. Active Agents 区域显示多张卡片。
4. 用户一眼看到 `test-writer` 是 `waiting_input`。
5. 用户点击该卡片进入详情。

### 9.3 查看任务详情与 step 历史

1. 详情页顶部显示 agent 名、状态、进度、最后更新时间。
2. 摘要区域展示模拟文案：`正在等待确认是否覆盖现有 mock；任务已完成 4/7 步。当前阻塞点是用户确认。`
3. 下方 step 时间线按时间倒序展示原始推送。
4. 用户可点击外链打开 CI / 日志页面占位。
5. 用户可从更多菜单执行归档、静音、标记完成。

### 9.4 旧 Bark 推送降级

1. 原型模拟一条不含 `agent_status` 的普通 Bark 推送。
2. 该消息不进入 Active Agent。
3. Dashboard 下半屏 History Timeline 出现一条 incoming memo。
4. 用户理解 BarkMate 兼容旧协议，但新字段会升级体验。

## 10. 页面需求

### 10.1 Onboarding / Empty State

目标：让新用户知道 BarkMate 不是普通 inbox，而是 agent 状态面板。

必须展示：

- 一句话定位；
- “Agent 卡片会原地更新，不会堆成消息流”的说明；
- curl 示例；
- `agent_status`、`task_id`、`progress` 三个关键字段解释；
- `Send demo push` 原型按钮，用于注入 mock 数据。

验收：

- 无数据时不出现空白列表；
- 用户能从页面复制 curl 示例；
- 示例包含 `agent_status` 和 `task_id`。

### 10.2 Dashboard

目标：首屏回答“我的 agent 现在怎么样”。

布局：

- 顶部：标题 `Agents` + 全局摘要；
- 摘要栏：running / waiting / blocked / failed 计数；
- 主区域：Active Agent 卡片网格；
- 下半屏：History Timeline；
- 顶部或悬浮区域：搜索与过滤入口。

AgentCard 必须包含：

- agent display name；
- status badge；
- latest step title；
- progress；
- updated time；
- server / source 的弱提示；
- pinned / muted 状态提示。

排序建议：

1. pinned；
2. waiting_input / blocked / failed；
3. running；
4. stale；
5. done；
6. updated_at 倒序。

验收：

- 6 张卡片在 iPhone 标准尺寸首屏可读；
- `waiting_input` 和 `blocked` 视觉上明显高于普通 running；
- 点击卡片进入详情；
- 长按或更多按钮展示操作菜单。

### 10.3 Agent Detail

目标：回答“这个 task 发生了什么、现在卡在哪里”。

必须展示：

- 状态头部：agent name、task id、status、progress、updated time；
- 最新 step；
- 摘要区域：支持 loading / summary / unavailable 三种状态；
- Step 时间线；
- 原始 body 支持 Markdown 样式预览；
- 操作：归档、静音、标记完成、复制 task curl 模板。

摘要区域原型状态：

| 状态 | UI |
|---|---|
| 默认 | `Summarize progress` 按钮 |
| loading | skeleton 或 spinner |
| success | ≤3 句摘要 + 当前阻塞点 |
| unavailable | 显示 `On-device summary unavailable on this device` |

验收：

- step 历史能表达同一 task 的多次推送；
- 摘要不替代原始 step，二者共同展示；
- failed / blocked task 的阻塞点在摘要区突出。

### 10.4 History Timeline

目标：承接已归档 agent、已完成 task、旧协议 Bark 推送和 memo。

必须展示：

- item 类型：agent task / incoming memo / manual memo；
- 标题、摘要、时间；
- 状态或标签；
- 点击进入对应详情或 memo 详情占位。

验收：

- 旧协议推送不会污染 Active Agent 区；
- 完成 / 归档后的 task 能在 History 找到。

### 10.5 Search / Filter

目标：展示未来 P0 搜索能力的交互路径。

必须展示：

- search input；
- scope chips：All / Agents / Steps / Memos；
- filters：status、agent_id、server、date；
- 结果类型标签。

验收：

- 搜索结果能混合展示 agent、step、memo；
- 用户能看出结果来自哪个 task。

### 10.6 Settings Preview

目标：让评审者理解 BarkMate 的隐私和接入边界。

必须展示：

- Server list；
- Add server 入口；
- Stale timeout 设置，默认 30 分钟；
- Apple Intelligence / On-device summary 开关占位；
- Notification preference；
- Privacy note：`No analytics. Summaries stay on device.`

## 11. 原型 Mock 数据

### 11.1 Active Agents

| agent | task | status | progress | latest step |
|---|---|---|---|---|
| backend-refactor | auth-migration-0420 | running | 3/8 | Refactoring auth middleware |
| test-writer | mock-coverage | waiting_input | 4/7 | Confirm overwrite existing mocks |
| e2e-runner | checkout-flow | done | 6/6 | All tests passed |
| log-analyzer | grafana-query | blocked | 2/5 | Missing Grafana token |
| deploy-bot | prod-release-1520 | failed | 5/6 | Migration failed on users table |
| dependency-updater | weekly-bump | stale | 1/4 | Installing packages |

### 11.2 Step 示例

```text
[10:23] running — Started backend refactor
[10:24] running — Updated auth.ts
[10:27] running — Fixed middleware type errors
[10:31] waiting_input — Confirm overwrite existing mocks
```

### 11.3 旧协议消息

```text
group=ci-alert
title=Build finished
body=main branch build completed in 12m32s
```

预期：进入 History Timeline，不创建 AgentTask。

## 12. 文案草案

### Empty State

```text
See every long-running agent as a living card.

Send Bark-compatible pushes with agent_status and task_id.
BarkMate will update the same task card instead of stacking messages.
```

### Dashboard Summary

```text
3 running · 1 waiting · 1 blocked
```

### Summary CTA

```text
Summarize progress
```

### Summary unavailable

```text
On-device summary is unavailable on this device. Raw steps are still shown below.
```

### Privacy

```text
Pushes are stored locally. On-device summaries never leave your iPhone.
```

## 13. 交互与视觉要求

- Dashboard 应该像状态驾驶舱，不像聊天 inbox。
- 状态颜色必须稳定、可学习，并兼顾浅色 / 深色模式可读性。
- `waiting_input`、`blocked`、`failed` 需要更强的视觉权重，因为它们代表用户需要行动。
- 卡片信息密度要高，但不能变成日志列表。
- Step 历史应该是“可追溯”，不是主视觉中心。
- 空状态必须偏行动导向，直接给 curl 模板。
- 摘要区域要明确是辅助理解，不能隐藏原始 step。

## 14. 非功能需求

| 类别 | 要求 |
|---|---|
| 设备 | iPhone 优先，按 iOS 17+ 设计 |
| 隐私 | 原型文案必须明确本地存储和 on-device summary |
| 可访问性 | 状态不能只依赖颜色，必须有文字 badge |
| 性能感知 | Dashboard mock 数据至少覆盖 20 个 task 的滚动状态 |
| 降级 | LLM、Live Activity、多服务器均要有不可用状态表达 |

## 15. 原型验收清单

- [ ] 空状态能解释 BarkMate 的核心概念；
- [ ] 能从空状态复制 curl 示例；
- [ ] Dashboard 展示至少 6 个 active agent；
- [ ] 每种状态都有可区分 badge；
- [ ] 同一 task 的多条 step 聚合到一张详情页；
- [ ] Agent Detail 包含摘要区域和原始 step 时间线；
- [ ] 旧协议消息进入 History，而不是 Active Agent；
- [ ] 卡片操作菜单包含置顶、归档、静音、标记完成；
- [ ] Search / Filter 路径存在，即使数据为 mock；
- [ ] Settings Preview 能表达服务器、隐私、stale threshold；
- [ ] 原型不承诺 V1.1 / V1.2 功能已经可用。

## 16. 待确认问题

1. `done` task 是否默认立即移入 History，还是在 Dashboard 保留一段时间后自动归档？
2. 缺少 `task_id` 时按 `agent_id` 聚合是否会导致同一 agent 的并发任务互相覆盖？是否需要在 onboarding 强提示推荐传 `task_id`？
3. `waiting_input` 与 `blocked` 的通知优先级是否都应映射为 timeSensitive？
4. 原型是否需要包含真实 iOS Widget / Live Activity 截图，还是只做概念画面？
5. Dashboard 卡片网格在小屏 iPhone 上采用 1 列还是 2 列？如果目标是首屏 6 张，2 列更合理，但信息密度更高。

## 17. 建议原型里程碑

| 阶段 | 产出 | 退出标准 |
|---|---|---|
| P0 Wireframe | 信息架构、关键流程、低保真页面 | 团队确认范围与页面结构 |
| P1 High-fidelity | Dashboard、Detail、Empty、Search、Settings 高保真 | 能进行产品评审和用户访谈 |
| P2 Clickable Demo | 使用 mock 数据串联流程 | 可演示从空状态到 agent 详情的完整路径 |
| P3 Implementation Spike | 可运行 SwiftUI mock 或 Web mock | 验证卡片密度、排序和状态表达 |

## 18. 与 V1.0 开发范围的关系

原型优先服务 iOS Phase 3 的 UI 决策，同时反向校验 Phase 2 的数据模型是否足够支撑产品语义。

- 原型确认后，Phase 2 应冻结 `agent_status`、`task_id`、`progress`、`eta` 字段行为。
- Dashboard 和 Detail 的交互应作为 Phase 3 的实现基线。
- 搜索、多服务器、加密配置在原型中保留路径，但不阻塞核心演示。
- Live Activity、Widget、设备端 LLM 总结可作为 V1.1 / V1.2 的概念预告，不应干扰 V1.0 主流程。
