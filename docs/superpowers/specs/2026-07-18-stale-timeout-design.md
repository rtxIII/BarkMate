# Stale Timeout —— 派生 stale + 可配阈值

- 日期: 2026-07-18
- 分支: main(在 alert-sound 合并之后)
- 状态: 已批准设计,待实现

## 背景与问题

Settings 屏 "Stale timeout · 30 min" 行(`BarkMate/App/Sources/Views/SettingsView.swift:68`)
是一个**双重占位**:

1. UI 是死的 —— 裸 `MCSettingRow`,无 Button/action,值 `"30 min"` 硬编码不可点。
2. 它声称的底层机制**根本不存在** —— 全库只有代码**消费** `AgentStatus.stale`
   (`AgentDashboardView` counts/buckets、`HistoryView` staleTasks),但**没有任何地方**
   把一个超时未更新的 running task 推断/降级为 stale。`.stale` 目前仅在 `ContentView`
   的 UI-test 种子数据里被硬赋值(`ContentView.swift:128,137`)。

`AgentStatus.stale` 注释即写明:"客户端推断:> N 分钟无更新且仍为 running"
(`Models/Enums.swift:14`),但该推断从未实现。

范围决策(已与用户确认):做**完整功能** —— stale 真正按阈值推断生效,且阈值可在 Settings 配置。

## 关键现状(已勘查)

- 一个 running task 是否 stale 的**唯一依据** = `updatedAt` 距 `now` 的间隔 + 阈值。
  `AgentTask.updatedAt` 在每次推送 upsert 时更新(`Models/AgentTask.swift:44`)。
- app **没有任何** scenePhase / Timer / 后台刷新。数据刷新靠:
  - Darwin 通知 `.itemDidArrive`(收到推送,`AgentDashboardView.swift:44`)
  - `.refreshable` 手动下拉(`AgentDashboardView.swift:172`)
- 所有 stale 消费点直读持久化 `status`(`AgentTask.status` 由 `statusRaw` 映射),
  派生方案下 `status` 永不为 `.stale`,故消费点需统一改走派生值。
- `bucket(for:)` 里 `.running` 与 `.stale` 同属 `.running` 桶
  (`MissionControl+Status.swift:154`),故派生成 stale 不会打乱 Dashboard 分栏,
  只改变 badge 文案与 HistoryView 顶部 STALE 段内容。
- `isTerminal`:`.stale` 为 false(`Theme.swift:115`),不属于终态。

## 决策记录(已确认)

1. **stale 机制 = 派生计算**(不落库)。不改写用户数据、无需定时器,契合现有 @Query 数据流。
   已知取舍:app 不在前台时不重算,不主动推送 stale 提醒 —— 接受。
2. **派生范围 = 全面生效**。所有直读 `status==.stale` 的消费点改走派生有效状态。
3. **阈值 = 预设档位** Off / 10 / 30 / 60 / 120 分钟,默认 30 min(与现有文案一致)。

## 架构总览

```
Settings: Stale timeout 行(可点)
   └─ StaleTimeoutStore(App Group UserDefaults)存阈值(默认 1800s,或 Off)
        │  读取
        ▼
AgentTask.effectiveStatus(now:threshold:) —— 派生:
   status==.running 且 now - updatedAt > threshold  →  .stale
   其它情况原样返回 status
        │  所有消费点改走
        ▼
   Dashboard counts/buckets · HistoryView staleTasks · AgentCardData
```

纯派生,零写库、零定时器。视图每次渲染(@Query 刷新 / Darwin 通知 / 下拉)带上新的
`now` 自然重算。

## 一、数据模型与阈值存储

### StaleThreshold(值类型,放 Models 包)

放 Models 而非 Store,因 `AgentTask.effectiveStatus` 需依赖它,而 `Models` 不能反向依赖 `Store`。

```swift
public enum StaleThreshold: Equatable, Sendable {
    case off
    case minutes(Int)

    public var seconds: TimeInterval?   // off → nil;.minutes(30) → 1800
    public var displayLabel: String     // off → "off";.minutes(30) → "30 min"
}

public enum StaleThresholdCatalog {
    public static let options: [StaleThreshold] =
        [.off, .minutes(10), .minutes(30), .minutes(60), .minutes(120)]
    public static let defaultThreshold: StaleThreshold = .minutes(30)
}
```

### AgentTask.effectiveStatus(派生纯函数,放 Models 包)

```swift
extension AgentTask {
    /// 派生有效状态:running 且超时未更新 → .stale;其余原样。
    public func effectiveStatus(now: Date, threshold: StaleThreshold) -> AgentStatus {
        guard status == .running,
              let limit = threshold.seconds,
              now.timeIntervalSince(updatedAt) > limit
        else { return status }
        return .stale
    }
}
```

边界:`now - updatedAt` 恰好等于阈值时**不算**超时(严格 `>`)。

### StaleTimeoutStore(放 Store 包,复用 AlertSoundStore 同款模式)

```swift
public struct StaleTimeoutStore: Sendable {
    public init(defaults: UserDefaults? = nil)   // nil → AppGroup.userDefaults
    public func setThreshold(_ t: StaleThreshold)
    public func threshold() -> StaleThreshold
}
```

- key `staleTimeout.minutes`,存 `Int`:正数=分钟;显式 **Off** 存 `-1` 哨兵;
  **未设过**(无 key)→ 返回 `StaleThresholdCatalog.defaultThreshold`(30 min)。
- 可注入 `UserDefaults` 便于测试,tearDown 用 `removePersistentDomain`。

## 二、消费点改造(全面走 effectiveStatus)

视图渲染时取一次 `now = Date()`,`threshold` 从 `StaleTimeoutStore` 读(Factory DI:
`Container.shared.staleTimeoutStore()`,视图用 `@Injected`)。

- `AgentDashboardView.DashboardContent`:`activeTasks` 分桶、`counts`(running/stale 计数)、
  `needsYouTasks`/`runningTasks` 的 `mcBucket` 判定 → 基于 effectiveStatus。
- `HistoryView`:`staleTasks`、timeline `filter` 的 `.stale` 判定 → 同样。
- 派生成 `.stale` 仍在 `.running` 桶,分栏不乱;badge `[RUNNING]`→`[STALE]`,
  HistoryView 顶部 STALE 段开始有内容。

## 三、Settings 行 + Picker

- `SettingsView.swift:68` Stale timeout 行:裸行 → `Button { showStalePicker = true }`,
  尾值 `MCSettingValue(currentThresholdLabel)`(如 `30 min` / `off`),
  配 `navigationDestination`。a11y id `settings-stale-timeout`。
- 新建 `StaleTimeoutPickerView`(Mission Control 风格,复用 `MCConsoleHeader`/`MCSettingRow`):
  单栏列出 `StaleThresholdCatalog.options`,点击 = 写 store + 打勾。
  a11y id `stale-timeout-picker` + `stale-option-<label>`。无试听,比 Alert sound 简单。

## 四、测试策略(TDD,与既有同构)

| 测试 | 位置 | 验证 |
|---|---|---|
| `StaleThresholdTests` | ModelsTests | seconds/label 映射;options 含 5 档;默认 30 |
| `EffectiveStatusTests` | ModelsTests | running+超时→stale;running 未超时→running;非 running 原样;Off→永不 stale;边界(=阈值不算超时) |
| `StaleTimeoutStoreTests` | StoreTests | 未设→默认30;设读往返;Off 哨兵;注入 suite |
| UI smoke | BarkMateUITests | 点 `settings-stale-timeout`→picker→点一档→勾选态 |

Dashboard/HistoryView 派生改造靠既有 UI 测试不回归 + 新增单测覆盖 `effectiveStatus`。

## 验收标准

1. Settings → 点 "Stale timeout" → 进入档位选择屏。
2. 点一档(如 60 min)→ 持久化;重进 app 保留;Settings 行显示 `60 min`。
3. 一个 running task 的 `updatedAt` 超过阈值 → Dashboard 显示 `[STALE]` badge、
   HistoryView 顶部 STALE 段出现该 task、stale 计数 +1。
4. 未超时的 running task 仍为 running;done/failed 等不受影响。
5. 阈值设 Off → 任何 running task 都不会被派生为 stale。
6. 新增单测全绿;既有测试不回归。

## 超出本次范围(YAGNI)

- 不落库、不做后台/定时把 running 改写为 .stale。
- 不做 stale 主动推送提醒。
- 不做自由分钟数输入(仅预设档位)。
