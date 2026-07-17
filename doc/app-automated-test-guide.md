# BarkAgent App 自动化测试运行手册

> 状态：当前实现基线
>
> 最后核对：2026-07-12
>
> 范围：iOS App、Notification Service Extension、共享存储、Bark 推送协议、BarkMate Server 依赖链路

## 1. 目标

本手册记录 BarkAgent App 自动化测试的执行顺序、真实 APNs 模拟器流程、验收证据、数据清理方式和当前未覆盖场景。

测试结论必须同时基于测试代码、进程退出码和测试结果文件；不能仅以 `/push` 返回 HTTP 200 判断通知功能通过。

当前测试入口：

| 层级 | 入口 | 验证内容 |
|---|---|---|
| Swift Package 单元/集成测试 | `swift test` | Models、Store、BarkService 的解析、路由、归档、解密、搜索和共享存储 |
| App 单元/集成测试 | `BarkMateTests` | Dashboard 映射、PushRegistrar、PendingQueueDrainer、Tab 路由 |
| 功能 UI 测试 | `BarkMateFunctionalSmokeTests` | Tab、Settings、Server、History、Search、Dashboard、Agent Detail 用户操作 |
| 截图回归 | `BarkMateScreenshotRegressionTests` | iPhone 17、英文、标准字体、竖屏下的关键页面像素差异 |
| 真实远程通知 E2E | `scripts/test-simulator-remote-push.sh` | Bark Server → APNs → NSE → App Group → App UI |
| Server 测试 | `npm test` | 注册、推送、鉴权、健康检查、隐私页和 Live Activity API |

## 2. 测试源文件

- App 单元/集成测试：`BarkMate/App/Tests/BarkMateTests/`
- App 功能 UI 测试：`BarkMate/App/UITests/BarkMateUITests/BarkMateFunctionalSmokeTests.swift`
- App 截图回归：`BarkMate/App/UITests/BarkMateUITests/BarkMateScreenshotRegressionTests.swift`
- 远程通知 UI 测试：`BarkMate/App/UITests/BarkMateUITests/BarkMateRemoteNotificationTests.swift`
- 加密 E2E 夹具：`BarkMate/App/Tests/BarkMateTests/RemotePushCryptoFixtureTests.swift`
- 远程通知编排脚本：`scripts/test-simulator-remote-push.sh`
- 单条通知发送脚本：`scripts/send-simulator-remote-push.sh`
- CI 配置：`.github/workflows/ci.yml`

## 3. 环境要求

从仓库根目录执行以下流程。

| 项目 | 要求 |
|---|---|
| macOS | 可运行当前 Xcode 和 iOS Simulator |
| Xcode | 包含项目要求的 iOS 26 Simulator runtime |
| XcodeGen | 可执行 `xcodegen generate` |
| Simulator | 默认 `iPhone 17 / iOS 26.5`，或通过环境变量覆盖 |
| 命令行工具 | `xcrun`、`sqlite3`、`curl`、`openssl`、`PlistBuddy` |
| App 标识 | `com.barkagent.ios` |
| App Group | `group.com.barkagent.shared` |
| 网络 | 模拟器和宿主机能够访问已配置的 Bark Server 与 APNs |

远程通知 E2E 应使用专用模拟器。发送脚本会读取共享数据库中的 Server 地址和 device key，并读取共享偏好中的 APNs device token；不得把这些值输出到测试日志。

默认模拟器可通过以下变量覆盖：

```bash
export BARKAGENT_SIMULATOR_DEVICE=booted
export BARKAGENT_SIMULATOR_DESTINATION='platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

## 4. 推荐执行顺序

```text
生成工程
  → Swift Package 测试
  → App 单元/集成测试
  → 功能 UI 测试
  → 截图回归
  → 真实 APNs E2E
  → 检查 xcresult 与测试数据清理结果
```

前一层失败时应先停止后续测试。真实 APNs E2E 依赖 App、NSE、共享存储和 Server，底层失败会放大为不稳定的 UI 超时。

### 4.1 生成 Xcode 工程

```bash
xcodegen generate --spec BarkMate/project.yml --project BarkMate
```

生成后确认 `BarkMate/BarkMate.xcodeproj` 包含：

- `BarkMateTests`
- `BarkMateUITests`
- `BarkMateRemoteNotificationTests.swift`
- `RemotePushCryptoFixtureTests.swift`

### 4.2 Swift Package 测试

```bash
(cd BarkMate/Packages/Models && swift test)
(cd BarkMate/Packages/Store && swift test)
(cd BarkMate/Packages/BarkService && swift test)
```

关键验收点：

- Store：App Group 多容器读写、Keychain CRUD、Keychain access group 与 entitlement 一致。
- BarkService：旧协议与 Agent 协议路由、任务聚合、重复推送幂等、解密成功、无密钥降级、PendingQueue、搜索。

### 4.3 App 单元/集成测试

```bash
xcodebuild \
  -project BarkMate/BarkMate.xcodeproj \
  -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:BarkMateTests \
  test
```

未设置 `BARKAGENT_REMOTE_PUSH_E2E` 时，三个加密夹具必须显示为 `Skipped`。这是安全隔离机制，防止常规测试写入固定 E2E key、IV 或 CryptoConfig。

### 4.4 功能 UI 测试

```bash
xcodebuild \
  -project BarkMate/BarkMate.xcodeproj \
  -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:BarkMateUITests/BarkMateFunctionalSmokeTests \
  test
```

这组测试通过 `BARKAGENT_UI_TESTING`、seed scenario 和可控 BarkClient 替身建立确定性数据。它验证用户界面和交互，但以下状态属于模拟状态，不等价于真实外部故障：

- APNs 注册失败横幅与跳转 Servers。
- 通知授权被拒横幅。
- Server 在线、离线、HTTP 503 和刷新结果。
- 测试用 device token。

### 4.5 截图回归

```bash
xcodebuild \
  -project BarkMate/BarkMate.xcodeproj \
  -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:BarkMateUITests/BarkMateScreenshotRegressionTests \
  test
```

当前基线固定为：

- iPhone 17。
- 竖屏。
- 英文 `en_US`。
- 标准 Dynamic Type 尺寸。
- 允许最多 `0.01`，即 1% 像素发生有效差异。

更新基线时显式设置：

```bash
BARKAGENT_RECORD_SCREENSHOTS=1 xcodebuild \
  -project BarkMate/BarkMate.xcodeproj \
  -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:BarkMateUITests/BarkMateScreenshotRegressionTests \
  test
```

基线变更必须由设计差异驱动，不能为了让失败测试变绿而直接覆盖。

### 4.6 BarkMate Server 测试

```bash
(cd BarkMateServer && npm run typecheck)
(cd BarkMateServer && npm test)
```

Server 测试通过后，只能说明 API 和 payload 构造符合契约；不能替代 APNs、NSE 和 App UI 的端到端验证。

## 5. 真实 APNs 模拟器 E2E

### 5.1 执行入口

```bash
./scripts/test-simulator-remote-push.sh
```

远程测试使用编译条件：

```text
BARKAGENT_REMOTE_PUSH_E2E
```

直接从 Xcode 或常规 `xcodebuild test` 运行时没有该条件，远程通知用例和加密夹具会主动 `Skipped`。必须通过编排脚本运行，不能单独运行依赖外部推送时序的 UI 用例。

### 5.2 注册前置条件

脚本首先启动 App 并处理通知授权。随后发送脚本要求共享状态中同时存在：

- 至少一个包含 Server 地址和 device key 的 Server。
- 已注册的 APNs device token。

缺少任一项时，脚本以以下错误停止：

```text
No complete simulator push registration was found.
```

该错误表示测试前置条件未建立，不直接表示 Dashboard、NSE 或通知展示功能失败。

### 5.3 验证链

每条真实通知采用三层证据：

1. Bark Server `/register` 和 `/push` 请求成功，`/push` 返回 HTTP 200。
2. NSE 在共享 SwiftData store 中写入或更新预期数据。
3. UI 测试在 Dashboard、Agent Detail 或 History 中找到唯一预期内容。

HTTP 200 只证明 Server 接受请求；没有共享库归档和 UI 断言时，不能判定通知链路通过。

### 5.4 执行阶段

| 顺序 | 场景 | 驱动动作 | 主要断言 |
|---:|---|---|---|
| 1 | 通知授权 | 启动 App；如果 SpringBoard 显示授权框则点击 Allow | App 主界面可用 |
| 2 | `running` | 发送 `progress=1/3` | Dashboard 唯一卡片、`01 running`、`33%` |
| 3 | `waiting_input` | 同一 task_id 发送 `progress=2/3` | 同一卡片进入 Needs You，显示 WAIT |
| 4 | `done` | 同一 task_id 发送 `progress=3/3` | 同一卡片进入 Settled；详情包含 3 条 push |
| 5 | 前台通知 | App 保持前台时发送 | 不重启 App 即刷新 Dashboard |
| 6 | 后台通知 | UI 测试按 Home；宿主机发送 | NSE 归档；激活 App 后显示卡片 |
| 7 | 终止态通知 | 确认 App 进程结束后发送 | NSE 归档；重新启动后显示卡片 |
| 8 | 旧 Bark 协议 | 发送不带 `agent_status` 的通知 | History → Incoming 显示标题和正文 |
| 9 | 加密成功 | 安装测试 key/IV；AES-256-CBC 加密；发送 ciphertext | NSE 解密后生成 AgentTask；Dashboard 显示 50% |
| 10 | 密钥缺失 | 删除共享 key 后再次发送有效密文 | History → Incoming 唯一显示 `Decryption Failed` |
| 11 | 降级元数据 | 查询失败 Inbox 项 | metadata 保留 ciphertext、IV、`reason=decryptionFailed` |
| 12 | 安全清理 | 删除测试 CryptoConfig、key、IV、AgentTask 和加密失败样本 | 无测试加密材料、AgentTask 和加密失败样本残留 |

### 5.5 前台、后台与终止态同步

- 前台测试先启动 UI 测试进程，确认 App 进程存在，再从宿主机发送通知。
- 后台测试按 Home 后等待系统状态稳定，再发送通知；测试等待 NSE 归档后重新激活 App。
- 终止态测试等待 App 进程完全消失后发送，并给系统保留最长 60 秒投递窗口。
- 进程判断使用精确标记 `UIKitApplication:com.barkagent.ios[`，避免把 UI test runner 误识别为 App。

### 5.6 加密夹具与清理

加密 E2E 使用固定测试材料，仅允许存在于专用模拟器：

- AES-256-CBC key：32 字节测试值。
- IV：16 字节测试值。
- Keychain 引用：`barkagent.remote-push-e2e.key` 和 `barkagent.remote-push-e2e.iv`。

执行顺序：

1. `testInstallSharedCryptoFixture` 写入 CryptoConfig、key 和 IV，并读回断言。
2. 加密成功通知完成后，`testRemoveSharedCryptoKeyFixture` 只删除 key，用于模拟密钥缺失。
3. 降级测试完成后，`testRemoveSharedCryptoFixture` 删除 CryptoConfig、key 和 IV。
4. 编排脚本删除 `simulator-e2e` AgentTask 和 `crypto-failure-e2e` Inbox 样本。

`legacy-e2e` 当前只在旧协议测试开始前清理，成功结束后仍会保留本轮 Inbox 样本；脚本中途失败时，加密 teardown 也可能未执行。需要无残留环境时，在 teardown 测试通过后执行：

```bash
shared_container_path=$(xcrun simctl get_app_container booted com.barkagent.ios group.com.barkagent.shared)
sqlite3 "$shared_container_path/BarkAgent.sqlite" \
  "DELETE FROM ZAGENTINBOXITEM WHERE ZGROUP IN ('simulator-e2e', 'legacy-e2e', 'crypto-failure-e2e');"
```

测试失败时若 teardown 未运行，应手动执行：

```bash
xcodebuild \
  -project BarkMate/BarkMate.xcodeproj \
  -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:BarkMateTests/RemotePushCryptoFixtureTests/testRemoveSharedCryptoFixture \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) BARKAGENT_REMOTE_PUSH_E2E' \
  test
```

## 6. 结果核验

`xcodebuild` 退出码为 0 仍需确认测试实际执行，避免 `-only-testing` 路径错误造成零测试假通过。

```bash
latest_result=$(ls -td /Users/mac/Library/Developer/Xcode/DerivedData/BarkMate-*/Logs/Test/*.xcresult | head -n 1)
xcrun xcresulttool get test-results tests --path "$latest_result"
```

核对规则：

- 指定用例存在于 `testNodes`。
- E2E 编译条件开启时结果为 `Passed`，不能是 `Skipped`。
- 常规 CI 条件下，远程通知用例和三个加密夹具必须是 `Skipped`。
- 失败时保留 xcresult、截图附件和 UI hierarchy；不得只依据控制台最后一行定位。

## 7. 常见失败定位

| 现象 | 首先验证 | 不能直接得出的结论 |
|---|---|---|
| `No complete simulator push registration...` | Server key、APNs token 是否已建立 | App 通知功能损坏 |
| `/push` 非 2xx | Server 地址、鉴权、网络和 API 响应 | NSE 或 Dashboard 有问题 |
| `/push` HTTP 200，但归档超时 | APNs 投递、NSE 日志、App Group、SwiftData store | Server 已完成端到端投递 |
| Inbox 出现 `Decryption Failed` | CryptoConfig、Keychain access group、key/IV、ciphertext | 通知完全丢失 |
| 数据库已归档，但 UI 找不到 | Darwin 通知、App 激活刷新、筛选条件、UI hierarchy | NSE 没有执行 |
| `xcodebuild` 为 0，但无测试节点 | `-only-testing` 标识和 Xcode 工程引用 | 测试通过 |
| UI 测试看不到系统横幅 | XCTest 自动化期间的系统展示策略 | 通知没有到达 |

## 8. 当前 CI 边界

`.github/workflows/ci.yml` 当前自动执行：

- Models、Store、BarkService 的 `swift test`。
- iOS Simulator Build。
- BarkMate Server typecheck 与 Vitest。

当前 CI **没有执行**：

- `BarkMateTests`。
- `BarkMateFunctionalSmokeTests`。
- `BarkMateScreenshotRegressionTests`。
- 真实 APNs 模拟器 E2E。

因此，本手册中的 App 单元/集成、功能 UI、截图和远程通知流程目前属于本地自动化，并非每个 PR 都会自动阻断。

## 9. 未覆盖场景

| 优先级 | 场景 | 当前替代证据 | 缺口 |
|---|---|---|---|
| P1 | App 测试进入 PR CI | 本地可运行全部测试 | PR 当前只 Build，不运行 App/UI 测试 |
| P1 | 点击系统通知横幅进入 App | 已验证真实 APNs 投递及横幅可显示 | XCTest 期间横幅被系统抑制，未自动验证点击与目标页面 |
| P1 | 真机 APNs | Simulator 真实 APNs 链路通过 | 未覆盖真机 token、签名、锁屏、后台调度差异 |
| P1 | 真实授权拒绝与重新开启 | seed 状态验证横幅和按钮 | 未自动操作系统授权拒绝、Settings 开启和回到 App |
| P1 | NSE 超时与持久化失败 | PendingQueue 单元/集成测试 | 未在真实扩展进程触发 `serviceExtensionTimeWillExpire`、App Group 不可写和恢复 drain |
| P1 | 重复、乱序和突发 APNs | 单元测试验证重复幂等；E2E 验证顺序状态流转 | 未以真实 APNs 验证重复 ID、乱序状态和并发 burst |
| P1 | E2E 失败后的自动 teardown | 成功路径会删除加密材料；手册提供手动清理命令 | 脚本中途失败时不会自动删除 key、IV、CryptoConfig；成功后仍保留本轮 `legacy-e2e` Inbox 样本 |
| P1 | 缺 progress 字段的进度渲染 | §5.4 每条进度用例都显式带 `progress`（1/3、2/3、3/3） | 未验证 running 缺 progress（应隐藏进度条而非画 0% 空条）与 done 缺 progress（保留旧值 → 条不满）的渲染，见 `doc/gap.md` P1/P2 |
| P2 | `%` 百分比格式进度 | §5.4 仅发 `1/3` 分数格式 | 未端到端验证 `65%` 形式的 progress 解析与渲染，见 `doc/gap.md` P5 |
| P2 | 富媒体附件 | ImageEnricher 使用受控网络替身测试 | 未以真实 APNs 验证图片下载、附件展示、超时和大图限制 |
| P2 | 多 Server 真实推送 | UI 和 PushRegistrar 测试覆盖 Server 管理 | 未验证两个真实 Server 独立注册、投递与删除后的行为 |
| P2 | Focus、通知摘要、Time Sensitive | Settings 开关交互通过 | 未验证系统 Focus/摘要策略下的实际展示 |
| P2 | 设备与可访问性矩阵 | iPhone 17 英文标准字号截图 | 未覆盖小屏、iPad、中文、深色模式、超大字号、VoiceOver |
| P2 | 性能和资源限制 | 功能测试通过 | 未自动采集冷启动、App 内存、NSE 24 MB、批量通知耗时 |
| P2 | Widget 与 Live Activity 远程更新 | 工程可构建，Server 有相关 API 测试 | 未覆盖真实远程更新、锁屏和 Widget 刷新 |
| P2 | Hooks 段展示内容 | scroll-through 断言了 Stale timeout / Mute rules / Alert sound / Analytics / Privacy / APNs；Re-run installer 有截图覆盖 | Settings「Hooks / Auto-installed」段与 Setup「Hook integrations」参考列表（静态文案）无功能断言；徽标 `active` 为硬编码，见 `doc/gap.md`「相关发现」 |

推荐补充顺序：

1. 把 `BarkMateTests` 和 `BarkMateFunctionalSmokeTests` 接入 PR CI。
2. 在真机测试计划中覆盖通知点击、授权恢复和锁屏/后台投递。
3. 增加真实 APNs 重复、乱序、burst 和 NSE 失败恢复测试。
4. 增加缺 progress 字段（running/done）与 `%` 格式的进度渲染用例（`doc/gap.md` P1/P2/P5）。
5. 增加设备、语言、Dynamic Type 和资源基准矩阵。

## 10. 退出标准

一次完整 App 自动化验收满足以下条件才可判定通过：

- Swift Package、App 单元/集成、功能 UI 和截图回归均无失败。
- 真实 APNs E2E 每次 `/push` 返回 2xx，并有对应共享库归档和 UI 断言。
- 加密成功与密钥缺失降级均通过。
- xcresult 中所有指定 E2E 用例实际执行，常规条件下受保护用例正确跳过。
- 固定测试 key、IV、CryptoConfig 和专用测试数据已通过自动或手动流程清理。
- 所有未覆盖 P1 场景在发布前有真机测试或明确风险接受记录。
