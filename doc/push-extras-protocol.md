# BarkMate Push Extras 协议

BarkMate 在原 Bark 协议（`https://github.com/Finb/Bark`）基础上，约定一组**客户端解析的自定义键**，让 push 携带 agent 元数据。**服务端不需要任何改动**——这些字段由 agent 脚本 / CI / hook 在发 push 时塞进 payload 顶层；BarkMate 客户端的 `PushParser` 取出后落到 SwiftData。

## 字段表

所有字段位于 push payload 的 `userInfo` 顶层（与现有 `url` / `group` / `image` 同级）。字段名**全部小写**（PushParser 做大小写规范化）。

| payload key | 类型 | ParsedPush 字段 | 说明 |
|---|---|---|---|
| `agent_id` | String | `agentIDOverride` → `agentID` | agent 命名空间（优先级最高）。提供时决定 `agentID`（Dashboard 分卡键 + 卡片 displayName）。**缺失时回退到 `group`**，再缺失则 `agentID = "default"`。用于让同 `group` 的多个 console 按项目/来源分卡（如 `claude:myproject`）。 |
| `group` | String | `group` → `agentID`（回退） | 通知分组（→ APNs `thread-id`）。`agent_id` 缺失时兼作 agentID。 |
| `task_id` | String | `taskID` | 任务唯一 ID（如 `auth-migration-0420`）。同 `agentID + task_id` 的多条 push 通过 `AgentTask.aggregateKey`（= `<agentID>::<taskID>`）聚合，原地更新 task、追加 step。 |
| `agent_status` | String | `agentStatus` | 状态码。**有此字段视为 agent push** → 落 `AgentTask` + `AgentStep`。缺失视为 legacy push → 落 `AgentInboxItem`（mock B 的 History → Incoming 段）。取值见下方。 |
| `progress` | String | `progress` | 进度，`"3/8"` 或 `"45%"` 字符串格式。Dashboard 渲染时 `MCProgressBar` / `MCRunCompactRow` 解析为 fraction。 |
| `eta` | ISO8601 String | `eta` | 预计完成时间。Dashboard 显示 "12m" / "1h" 相对值。 |
| `icon` | URL String | `iconURL` | agent 头像 URL（暂未在 UI 大范围使用）。 |
| `markdown` | String | `body` (bodyType=markdown) | 提供时 `body` 改为 markdown 渲染；否则用 `aps.alert.body` 平文。 |
| `id` | String | `id` | 推送唯一 ID（用于 NSE 重传幂等）。缺失时基于 payload 内容稳定哈希（`PushParser.deterministicUUID`）。 |

继承自原 Bark 协议的字段（`url` / `image` / `subtitle` / `ciphertext` 等）保持原语义，不在此重列。

## `agent_status` 取值与 UI 映射

PayLoad 字段 `agent_status` 取以下五个值之一（小写，含下划线）。客户端会渲染为 mock B 的方括号状态码 + HUD 色板（`MissionControl.Status.render(for:)`）：

| payload 值 | AgentStatus case | UI 渲染 |
|---|---|---|
| `running` | `.running` | "Running" 段 · `[ RUN ]` · 青色进度条 |
| `waiting_input` | `.waitingInput` | "Needs you" 段 · `[ WAIT ]` · 琥珀色带 + glow |
| `blocked` | `.blocked` | "Needs you" 段 · `[ STUCK ]` · 橙色带 + glow |
| `done` | `.done` | "Settled" 段 · `[ DONE ]` · 酸橙色 |
| `failed` | `.failed` | "Settled" 段 · `[ FAIL ]` · 品红 + 橙色带（mock B 把 fail 与 done 并列在 settled） |

**第六个 case `.stale` 不通过 payload 设置**，是客户端推断状态（见下方 Stale 行为）。

## 多 console 分卡（installer 自动派生 `agent_id`）

`install.sh` 生成的 `bark-push` 在 Claude Code 钩子模式下，会从 hook stdin 的 `cwd` 取项目名，自动令 `agent_id = group = "claude:<项目名>"`：

- **不同项目的 console** → `agent_id` 不同 → aggregateKey 不同 → Dashboard 分卡、通知按项目分线程。
- **同项目不同 session** → `agent_id` 相同、`task_id`（= `session_id`）不同 → 同项目下按 session 分卡，卡名同为 `claude:<项目名>` 在列表里聚拢。
- `cwd` 缺失（老 hook 版本）→ 回退 `agent_id = "claude"`，即旧的单卡行为；`task_id` 兜底绑定项目名（`session-<proj>`），避免多 console 塌缩成同一 task。

自建 agent 用纯 flags 调用时，直接用 `--agent`/`--task` 控制这两个维度，不经过上述 cwd 派生。

## Legacy 兼容（无 `agent_status` 的 push）

旧 Bark push（即 `agent_status` 字段缺失）走另一条路径：
- 落 `AgentInboxItem`（SwiftData 模型，对应 `MemoSource` 时代的 `.incoming`）
- 在 BarkMate UI 显示 `[ BARK ]` 青色徽章
- 归到 **History → Incoming** 段，**不进入** Agents tab 的 Triage

旧版 Bark 用户的所有 push 在 BarkMate 中都按此路径处理，无破坏性变化。客户端解密、image 附件等其它处理仍照旧。

## Stale 行为（客户端推断，非协议字段）

`AgentStatus.stale` **不通过 payload 设置**。当一个 task 长时间没有新 push 更新（默认阈值在 Settings → Agent behavior → Stale timeout 配置，默认 30 min），客户端会把它视为 stale：
- mock B 的 History 顶部 STALE AGENTS heads-up 段独立高亮列出
- 同时在 timeline 中以 `[ STALE ]` 灰度徽章显示
- 移出 Dashboard 的 Running / Needs you 桶

**当前实现**：仅当 `task.status == .stale` 时才显示在 stale 段，没有后台 worker 自动 demote。后续可加 timer / launch-time 扫描 `running > N min` 的 task 改写 status。

## curl 示例

### 一条 waiting_input push（"Needs you" 大卡）
```bash
curl -X POST "https://barkmate.we2.xyz/YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "test-writer",
    "body": "Confirm overwrite existing mocks?",
    "group": "test-writer",
    "task_id": "TASK-0420",
    "agent_status": "waiting_input",
    "progress": "4/7"
  }'
```

### 一条 running 进度 push（"Running" 紧凑行）
```bash
curl -X POST "https://barkmate.we2.xyz/YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "backend-refactor",
    "body": "auth-migration · 3/8 files",
    "group": "backend-refactor",
    "task_id": "auth-migration-0420",
    "agent_status": "running",
    "progress": "3/8"
  }'
```

### 一条 legacy push（无 agent 字段 → AgentInboxItem）
```bash
curl -X POST "https://barkmate.we2.xyz/YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Build finished",
    "body": "main branch · 12m 32s"
  }'
```
归到 History → Incoming，徽章 `[ BARK ]`。

## 字段命名常见错误

- ❌ `agentId` / `agentStatus`（驼峰） — payload 必须用 snake_case（与原 Bark 协议风格一致）
- ✅ `agent_id` — 现已支持，优先于 `group` 决定 agentID（分卡键）。缺失时回退 `group`，仍缺失回退 `"default"`。多个 console 想按项目分卡就发 `agent_id`（如 `claude:myproject`）。
- ❌ `progress_step` / `progress_total` —— **没有这两个字段**；用单一 `progress` 字符串，如 `"3/7"` 或 `"45%"`
- ❌ `agent_status: "wait"` —— 必须是 `waiting_input` 等完整 raw value，`wait` / `stuck` 等是 UI badge 文案

## 实现位置（BarkMate 代码路径）

- 协议解析：`BarkMate/Packages/BarkService/Sources/BarkService/PushParser.swift`
- 路由：`BarkMate/Packages/BarkService/Sources/BarkService/AgentRouter.swift`（`AgentRoute.agent` vs `.inbox`）
- 落库：`BarkMate/Packages/BarkService/Sources/BarkService/PushArchiver.swift`
- 数据模型：`BarkMate/Packages/Models/Sources/Models/{AgentTask,AgentStep,AgentInboxItem}.swift`
- AgentStatus 枚举：`BarkMate/Packages/Models/Sources/Models/Enums.swift`
- Schema：`BarkMate/Packages/Models/Sources/Models/SchemaV1.swift`（V1，应用未发布，尚未冻结）
- UI 映射：`BarkMate/Packages/DesignSystem/Sources/DesignSystem/Tokens/MissionControl+Status.swift`
