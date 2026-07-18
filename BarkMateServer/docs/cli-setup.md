# BarkMate CLI 接入

> 一行命令把 BarkMate 推送钩在 Claude Code / Codex CLI / OpenCode 上。所有 agent 共用一个 `bark-push` 的纯 shell CLI 走 HTTPS。

## 快速开始

### 第 1 步：拿到 device key

打开 iPhone 上的 BarkMate App → **设置 → 服务器**，复制顶部那串 device key（22 个字母数字）。

### 第 2 步：一行安装

```bash
curl -fsSL https://barkagent.we2.xyz/install.sh | BARK_KEY=your_key sh
```

脚本会：

- 把 `bark-push` 装到 `/usr/local/bin`（不可写时退到 `~/.local/bin`）
- 自动检测 `~/.claude` / `~/.codex` / `~/.config/opencode`，写入对应钩子
- 未安装的工具静默跳过；重跑安全（每次写入前 `.bak.<ts>` 备份）

### 第 3 步：发一条测试推送

```bash
bark-push --agent demo --task hello --status running --title "first push"
```

iPhone 弹出标题为 **first push** 的通知即接入成功。没收到？看下文 [故障排查](#故障排查)。

### 第 4 步（仅 Codex 用户）：在 TUI 内批准钩子

首次启动 `codex` 后执行 `/hooks`，把新出现的 `PermissionRequest` 钩子选 **Always allow**。Claude Code 和 OpenCode 无此步骤。

## 自动接入的工具

| Agent | 配置文件 | 触发事件 → 推送状态 |
|---|---|---|
| Claude Code | `~/.claude/settings.json` | `Notification` → waiting_input · `Stop` → done |
| Codex CLI | `~/.codex/config.toml` + `~/.codex/hooks.json` | `notify`/`SessionStart` → running · `PermissionRequest` → waiting_input · `Stop` → done |
| OpenCode | `~/.config/opencode/plugins/barkmate.ts` | `session.created` → running · `session.idle` → done · `session.error` → failed · `permission.asked` → waiting_input |

`SubagentStop` 默认静默，避免子任务噪音轰炸。

**多个 Claude 窗口自动分卡**：Claude Code 钩子会按当前项目目录（`cwd`）把推送归到 `claude:<项目名>`，不同项目的 console 在 Dashboard 上分成独立卡片、通知也按项目分线程；同项目的多个会话按 session 各自成卡。无需手动配置。改动过安装脚本后需**重跑安装命令**才会重新生成 `bark-push` 生效。

## 自建 agent 直接调 bark-push

bark-push 也支持纯 flags 形式，自定义脚本可以这样推：

```bash
bark-push --agent backend --task auth-0420 --status running \
          --progress 3/8 --title "Refactor auth" \
          --eta 2026-06-04T12:00:00Z
```

`--status` 取 `running | waiting_input | done | failed`，其他字段全部可选。完整参数：`bark-push --help`。

## 自部署 bark-server

如果你跑了自己的 bark-server 实例，把 `BARK_SERVER` 也传进去：

```bash
curl -fsSL https://barkagent.we2.xyz/install.sh | \
  BARK_KEY=your_key BARK_SERVER=https://your.server.example sh
```

`BARK_KEY` 和 `BARK_SERVER` 会被烧进生成的 `bark-push` 作为默认值；runtime 用同名环境变量可以覆盖。

## 重装 / 卸载

**重装**：直接重跑第 2 步的安装命令，旧 hook 自动备份为 `.bak.<timestamp>`。

**卸载**：

```bash
rm "$(command -v bark-push)"
```

然后手动从 `~/.claude/settings.json`、`~/.codex/config.toml`、`~/.codex/hooks.json`、`~/.config/opencode/opencode.json` 移除带 `barkmate` 或 `bark-push` 字样的条目；备份文件可参照还原。

## 故障排查

**测试推送收不到**：先在 iPhone 上确认 BarkMate App 已登录、通知权限已开。再 `curl -i "https://barkagent.we2.xyz/your_key" -d "title=ping"`，若返回 200 但还是没声音，去 App **设置 → 推送测试** 排查 APNs。

**Codex 钩子不触发**：90% 是没在 TUI 里执行 `/hooks` 批准。Codex 出于安全要求人工 opt-in，新写入 `hooks.json` 不会自动生效。

**`bark-push: jq required for --from adapter`**：装 `jq`（`brew install jq` / `apt install jq`）后重试。jq 仅在 hook 模式需要；纯 flags 调用不依赖它。

**PATH 找不到 bark-push**：脚本输出会提示 `/usr/local/bin` 不可写、已退到 `~/.local/bin` 的情况；按提示把它加到 PATH 即可。

## 协议 / 隐私

- bark-push 只发 `POST <server>/<device_key>` 一种请求，payload 是普通 form-urlencoded
- BarkMate 服务端不记录推送内容，KV 只存 `device_key → APNs token`
- 完整隐私政策：[/privacy](/privacy)
