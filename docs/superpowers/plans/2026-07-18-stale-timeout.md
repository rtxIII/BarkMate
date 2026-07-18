# Stale Timeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Settings 的 "Stale timeout" 行可点击配置阈值,并让一个 running task 在 `updatedAt` 超过阈值时被**派生**为 stale,在 Dashboard / History 全面生效。

**Architecture:** 纯派生,零写库、零定时器。`AgentTask.effectiveStatus(now:threshold:)` 在视图渲染时按 `updatedAt` 惰性计算;阈值存 App Group `UserDefaults`,Settings 可配。所有直读 `status==.stale` 的消费点改走派生有效状态。

**Tech Stack:** Swift 6 / SwiftUI / SwiftData / Factory DI / XcodeGen / XCTest。

## Global Constraints

- 平台 iOS 18.0+;Swift 6.0(Models/Store 包)/ 5.10(App)。`SWIFT_STRICT_CONCURRENCY: complete`。
- `StaleThreshold` 值类型放 **Models 包**(`AgentTask.effectiveStatus` 需依赖它,Models 不能反向依赖 Store)。
- `StaleTimeoutStore`(依赖 UserDefaults)放 **Store 包**,复用 `AlertSoundStore` 同款模式。
- 阈值档位:`Off / 10 / 30 / 60 / 120` 分钟,默认 30。存 `Int`:正数=分钟;Off 存 `-1` 哨兵;无 key → 默认 30。
- key `staleTimeout.minutes`;App Group identifier `group.com.barkagent.shared`。
- 派生边界:`now - updatedAt` 严格 `>` 阈值才算 stale(恰好等于不算)。仅 `status==.running` 可被派生为 stale。
- 纯派生:不落库、不定时改写 running→stale、不做 stale 推送提醒。
- 测试注入自定义 `UserDefaults(suiteName:)`,tearDown 用 `removePersistentDomain`。
- `.xcodeproj` 被 gitignore,从 `project.yml` 生成 —— 提交时勿 `git add` 工程文件。
- 模拟器用 `iPhone 17`(iPhone 16 不存在)。

---

### Task 1: StaleThreshold 值类型 + Catalog(Models 包)

**Files:**
- Modify: `BarkMate/Packages/Models/Sources/Models/Enums.swift`(追加,不改动现有枚举)
- Test: `BarkMate/Packages/Models/Tests/ModelsTests/StaleThresholdTests.swift`

**Interfaces:**
- Consumes: 无
- Produces:
  - `enum StaleThreshold: Equatable, Hashable, Sendable`,`case off` / `case minutes(Int)`
    - `var seconds: TimeInterval?`(off → nil;`.minutes(30)` → 1800)
    - `var displayLabel: String`(off → "off";`.minutes(30)` → "30 min")
  - `enum StaleThresholdCatalog`:`static let options: [StaleThreshold]`(5 档)、`static let defaultThreshold: StaleThreshold`(`.minutes(30)`)

- [ ] **Step 1: Write the failing test**

Create `BarkMate/Packages/Models/Tests/ModelsTests/StaleThresholdTests.swift`:
```swift
import XCTest
@testable import Models

final class StaleThresholdTests: XCTestCase {

    func testSecondsMapping() {
        XCTAssertNil(StaleThreshold.off.seconds)
        XCTAssertEqual(StaleThreshold.minutes(30).seconds, 1800)
        XCTAssertEqual(StaleThreshold.minutes(10).seconds, 600)
    }

    func testDisplayLabel() {
        XCTAssertEqual(StaleThreshold.off.displayLabel, "off")
        XCTAssertEqual(StaleThreshold.minutes(30).displayLabel, "30 min")
        XCTAssertEqual(StaleThreshold.minutes(120).displayLabel, "120 min")
    }

    func testCatalogOptions() {
        XCTAssertEqual(
            StaleThresholdCatalog.options,
            [.off, .minutes(10), .minutes(30), .minutes(60), .minutes(120)]
        )
    }

    func testCatalogDefault() {
        XCTAssertEqual(StaleThresholdCatalog.defaultThreshold, .minutes(30))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BarkMate/Packages/Models && swift test --filter StaleThresholdTests`
Expected: FAIL,"cannot find 'StaleThreshold' in scope"。

- [ ] **Step 3: Write minimal implementation**

在 `BarkMate/Packages/Models/Sources/Models/Enums.swift` 末尾追加:
```swift

/// Running task 超时判定阈值。`.off` = 关闭 stale 推断。
public enum StaleThreshold: Equatable, Hashable, Sendable {
    case off
    case minutes(Int)

    /// 秒数;`.off` 无阈值返回 nil。
    public var seconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .minutes(let m): return TimeInterval(m * 60)
        }
    }

    /// Settings 行 / picker 展示文案。
    public var displayLabel: String {
        switch self {
        case .off: return "off"
        case .minutes(let m): return "\(m) min"
        }
    }
}

public enum StaleThresholdCatalog {
    /// Settings picker 档位。
    public static let options: [StaleThreshold] =
        [.off, .minutes(10), .minutes(30), .minutes(60), .minutes(120)]

    /// 未配置时的默认阈值。
    public static let defaultThreshold: StaleThreshold = .minutes(30)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BarkMate/Packages/Models && swift test --filter StaleThresholdTests`
Expected: PASS(4 tests)。

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/Packages/Models/Sources/Models/Enums.swift BarkMate/Packages/Models/Tests/ModelsTests/StaleThresholdTests.swift
git commit -m "feat: add StaleThreshold value type + catalog"
```

---

### Task 2: AgentTask.effectiveStatus(派生纯函数,Models 包)

**Files:**
- Create: `BarkMate/Packages/Models/Sources/Models/AgentTask+Stale.swift`
- Test: `BarkMate/Packages/Models/Tests/ModelsTests/EffectiveStatusTests.swift`

**Interfaces:**
- Consumes: `StaleThreshold`(Task 1);`AgentTask`(`Models/AgentTask.swift`)、`AgentStatus`。
- Produces: `AgentTask.effectiveStatus(now: Date, threshold: StaleThreshold) -> AgentStatus`

- [ ] **Step 1: Write the failing test**

Create `BarkMate/Packages/Models/Tests/ModelsTests/EffectiveStatusTests.swift`:
```swift
import XCTest
import SwiftData
@testable import Models

final class EffectiveStatusTests: XCTestCase {

    private func makeTask(status: AgentStatus, updatedAt: Date) -> AgentTask {
        AgentTask(
            aggregateKey: "a::_",
            agentID: "a",
            displayName: "Task",
            status: status,
            updatedAt: updatedAt
        )
    }

    func testRunningPastThresholdBecomesStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .running, updatedAt: Date(timeIntervalSince1970: 10_000 - 1801))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), .stale)
    }

    func testRunningWithinThresholdStaysRunning() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .running, updatedAt: Date(timeIntervalSince1970: 10_000 - 1799))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), .running)
    }

    func testExactlyAtThresholdIsNotStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .running, updatedAt: Date(timeIntervalSince1970: 10_000 - 1800))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), .running)
    }

    func testNonRunningIsNeverStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let old = Date(timeIntervalSince1970: 0)
        for status in [AgentStatus.waitingInput, .blocked, .done, .failed] {
            let task = makeTask(status: status, updatedAt: old)
            XCTAssertEqual(task.effectiveStatus(now: now, threshold: .minutes(30)), status)
        }
    }

    func testOffNeverStale() {
        let now = Date(timeIntervalSince1970: 10_000)
        let task = makeTask(status: .running, updatedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(task.effectiveStatus(now: now, threshold: .off), .running)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BarkMate/Packages/Models && swift test --filter EffectiveStatusTests`
Expected: FAIL,"value of type 'AgentTask' has no member 'effectiveStatus'"。

- [ ] **Step 3: Write minimal implementation**

Create `BarkMate/Packages/Models/Sources/Models/AgentTask+Stale.swift`:
```swift
//
//  AgentTask+Stale.swift
//  Models
//
//  Stale 派生:running 且 updatedAt 超过阈值 → .stale。不落库,视图渲染时惰性计算。
//

import Foundation

extension AgentTask {
    /// 派生有效状态。仅 running 且 `now - updatedAt` 严格超过阈值时返回 `.stale`,其余原样。
    public func effectiveStatus(now: Date, threshold: StaleThreshold) -> AgentStatus {
        guard status == .running,
              let limit = threshold.seconds,
              now.timeIntervalSince(updatedAt) > limit
        else { return status }
        return .stale
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BarkMate/Packages/Models && swift test --filter EffectiveStatusTests`
Expected: PASS(5 tests)。

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/Packages/Models/Sources/Models/AgentTask+Stale.swift BarkMate/Packages/Models/Tests/ModelsTests/EffectiveStatusTests.swift
git commit -m "feat: add AgentTask.effectiveStatus derived stale computation"
```

---

### Task 3: StaleTimeoutStore(阈值持久化,Store 包)

**Files:**
- Create: `BarkMate/Packages/Store/Sources/Store/StaleTimeoutStore.swift`
- Test: `BarkMate/Packages/Store/Tests/StoreTests/StaleTimeoutStoreTests.swift`

**Interfaces:**
- Consumes: `StaleThreshold` / `StaleThresholdCatalog`(Task 1,Store 已依赖 Models);`AppGroup.userDefaults`(`Store/AppGroup.swift:48`)。
- Produces:
  - `struct StaleTimeoutStore: Sendable`
  - `init(defaults: UserDefaults? = nil)`
  - `func setThreshold(_ threshold: StaleThreshold)`
  - `func threshold() -> StaleThreshold`

- [ ] **Step 1: Write the failing test**

Create `BarkMate/Packages/Store/Tests/StoreTests/StaleTimeoutStoreTests.swift`:
```swift
import XCTest
import Models
@testable import Store

final class StaleTimeoutStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: StaleTimeoutStore!

    override func setUpWithError() throws {
        suiteName = "StaleTimeoutStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        self.defaults = defaults
        store = StaleTimeoutStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        store = nil; defaults = nil; suiteName = nil
    }

    func testUnsetReturnsDefault() {
        XCTAssertEqual(store.threshold(), StaleThresholdCatalog.defaultThreshold)
    }

    func testMinutesRoundTrip() {
        store.setThreshold(.minutes(60))
        XCTAssertEqual(store.threshold(), .minutes(60))
    }

    func testOffRoundTrip() {
        store.setThreshold(.off)
        XCTAssertEqual(store.threshold(), .off)
    }

    func testOverwriteThreshold() {
        store.setThreshold(.minutes(10))
        store.setThreshold(.minutes(120))
        XCTAssertEqual(store.threshold(), .minutes(120))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BarkMate/Packages/Store && swift test --filter StaleTimeoutStoreTests`
Expected: FAIL,"cannot find 'StaleTimeoutStore' in scope"。

- [ ] **Step 3: Write minimal implementation**

Create `BarkMate/Packages/Store/Sources/Store/StaleTimeoutStore.swift`:
```swift
//
//  StaleTimeoutStore.swift
//  Store
//
//  Stale timeout 阈值持久化,存 App Group 共享 UserDefaults。
//  存 Int:正数 = 分钟;-1 = Off 哨兵;无 key = 默认 30。
//

import Foundation
import Models

public struct StaleTimeoutStore: @unchecked Sendable {

    private static let key = "staleTimeout.minutes"
    private static let offSentinel = -1

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.userDefaults
    }

    public func setThreshold(_ threshold: StaleThreshold) {
        switch threshold {
        case .off:
            defaults.set(Self.offSentinel, forKey: Self.key)
        case .minutes(let m):
            defaults.set(m, forKey: Self.key)
        }
    }

    public func threshold() -> StaleThreshold {
        guard defaults.object(forKey: Self.key) != nil else {
            return StaleThresholdCatalog.defaultThreshold
        }
        let raw = defaults.integer(forKey: Self.key)
        return raw == Self.offSentinel ? .off : .minutes(raw)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BarkMate/Packages/Store && swift test --filter StaleTimeoutStoreTests`
Expected: PASS(4 tests)。

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/Packages/Store/Sources/Store/StaleTimeoutStore.swift BarkMate/Packages/Store/Tests/StoreTests/StaleTimeoutStoreTests.swift
git commit -m "feat: add StaleTimeoutStore threshold persistence"
```

---

### Task 4: DI 注册 StaleTimeoutStore(App)

**Files:**
- Modify: `BarkMate/App/Sources/DI/Container+App.swift`

**Interfaces:**
- Consumes: `StaleTimeoutStore`(Task 3);测试注入沿用 `ProcessInfo.barkAgentTestDefaults`(`Container+App.swift:145`)。
- Produces: `Container.shared.staleTimeoutStore() -> StaleTimeoutStore`,供 Task 5/6 视图用。

- [ ] **Step 1: 注册**

Modify `BarkMate/App/Sources/DI/Container+App.swift`,在 `alertSoundStore` Factory 之后新增:
```swift
    /// Stale timeout 阈值存储(共享 UserDefaults)。
    var staleTimeoutStore: Factory<StaleTimeoutStore> {
        self {
            StaleTimeoutStore(defaults: ProcessInfo.processInfo.barkAgentTestDefaults)
        }
        .singleton
    }
```

- [ ] **Step 2: 编译校验**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodegen generate >/dev/null 2>&1
xcodebuild -project BarkMate.xcodeproj -scheme BarkMate -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -4
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/App/Sources/DI/Container+App.swift
git commit -m "feat: register StaleTimeoutStore in App DI"
```

---

### Task 5: 消费点改走 effectiveStatus(Dashboard + History)

**Files:**
- Modify: `BarkMate/App/Sources/Views/AgentDashboardView.swift`
- Modify: `BarkMate/App/Sources/Views/HistoryView.swift`

**Interfaces:**
- Consumes: `AgentTask.effectiveStatus(now:threshold:)`(Task 2);`Container.shared.staleTimeoutStore()`(Task 4)。
- Produces: `AgentCardData.fromTask(_:status:)` 与 `HistoryItemData.fromTask(_:status:)` 增加显式 `status` 参数(派生值由调用方传入);Dashboard buckets/counts 与 History staleTasks/timeline 基于派生有效状态渲染。

**说明:** `fromTask` 当前内部读 `task.status`(`AgentDashboardView.swift:457,515`)。改为接受显式 `status: AgentStatus` 参数,派生在视图层(有 `now`)完成,mapper 保持纯。

- [ ] **Step 1: 改 AgentCardData.fromTask 接受显式 status**

Modify `AgentDashboardView.swift:452-466`,把 `fromTask` 签名改为带 `status` 参数:
```swift
extension AgentCardData {
    static func fromTask(_ task: AgentTask, status: AgentStatus) -> AgentCardData {
        AgentCardData(
            id: task.id,
            agentName: task.displayName,
            taskID: task.taskID,
            status: status,
            latestStep: task.latestStepTitle ?? "No step yet",
            progressLabel: task.progress,
            progressFraction: Self.progressFraction(from: task.progress),
            etaLabel: Self.etaLabel(from: task.eta),
            updatedLabel: Self.relativeLabel(from: task.updatedAt),
            isPinned: task.isPinned,
            isMuted: task.isMuted
        )
    }
```
(保留 `progressFraction`/`etaLabel`/`relativeLabel` 等静态方法不变。)

- [ ] **Step 2: 改 HistoryItemData.fromTask 接受显式 status**

Modify `AgentDashboardView.swift:512` 起的 `HistoryItemData.fromTask`:签名改为 `static func fromTask(_ task: AgentTask, status: AgentStatus) -> HistoryItemData`,并把方法体内 `switch task.status` 改为 `switch status`。方法体其余逻辑不变。

- [ ] **Step 3: 在 DashboardContent 注入 store + 派生 helper**

Modify `AgentDashboardView.swift` 的 `DashboardContent`(`:61` 起)。在 `@Environment(\.modelContext)` 之后新增:
```swift
    @Injected(\.staleTimeoutStore) private var staleTimeoutStore: StaleTimeoutStore

    private func effective(_ task: AgentTask) -> AgentStatus {
        task.effectiveStatus(now: Date(), threshold: staleTimeoutStore.threshold())
    }
```

- [ ] **Step 4: DashboardContent 各派生属性改走 effective**

把以下计算属性(`:79-130`)全部改为基于 `effective($0)`:
```swift
    private var activeTasks: [AgentTask] {
        tasks
            .filter { !effective($0).isTerminal && !$0.isArchived }
            .sorted(by: prioritySort)
    }

    private var needsYouTasks: [AgentCardData] {
        activeTasks
            .filter { effective($0).mcBucket == .needsYou }
            .map { AgentCardData.fromTask($0, status: effective($0)) }
    }

    private var runningTasks: [AgentCardData] {
        activeTasks
            .filter { effective($0).mcBucket == .running }
            .map { AgentCardData.fromTask($0, status: effective($0)) }
    }

    private var settledDoneTasks: [AgentCardData] {
        tasks
            .filter { !$0.isArchived && effective($0) == .done }
            .map { AgentCardData.fromTask($0, status: effective($0)) }
    }

    private var settledFailedTasks: [AgentCardData] {
        tasks
            .filter { !$0.isArchived && effective($0) == .failed }
            .map { AgentCardData.fromTask($0, status: effective($0)) }
    }

    private var counts: AgentHeroCounts {
        AgentHeroCounts(
            running: tasks.filter { !$0.isArchived && effective($0) == .running }.count,
            waiting: tasks.filter { !$0.isArchived && effective($0) == .waitingInput }.count,
            blocked: tasks.filter { !$0.isArchived && effective($0) == .blocked }.count,
            failed: tasks.filter { !$0.isArchived && effective($0) == .failed }.count,
            stale: tasks.filter { !$0.isArchived && effective($0) == .stale }.count,
            done: tasks.filter { effective($0) == .done }.count,
            active: tasks.filter { !$0.isArchived && !effective($0).isTerminal }.count
        )
    }
```

`historyPreview`(`:121`)改为:
```swift
    private var historyPreview: [HistoryItemData] {
        let terminalTasks = tasks
            .filter { effective($0).isTerminal || $0.isArchived }
            .map { HistoryItemData.fromTask($0, status: effective($0)) }
        let inboxRows = inboxItems.map(HistoryItemData.fromInboxItem)
        return (terminalTasks + inboxRows)
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(3)
            .map { $0 }
    }
```

- [ ] **Step 5: prioritySort 与 ShareLink 调用改走 effective**

`prioritySort`(`:376`)的 `status.sortPriority` 改为 `effective(...).sortPriority`:
```swift
    private func prioritySort(_ lhs: AgentTask, _ rhs: AgentTask) -> Bool {
        if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
        let lp = effective(lhs).sortPriority
        let rp = effective(rhs).sortPriority
        if lp != rp { return lp < rp }
        return lhs.displayName < rhs.displayName
    }
```

`AgentDashboardView.swift:365` 的 ShareLink:`AgentCardData.fromTask(task)` → `AgentCardData.fromTask(task, status: effective(task))`。

- [ ] **Step 6: HistoryView 走 effectiveStatus**

Modify `HistoryView.swift`。文件顶部 `import` 区加 `import Factory`。在 `@State private var filter` 之后新增:
```swift
    @Injected(\.staleTimeoutStore) private var staleTimeoutStore: StaleTimeoutStore

    private func effective(_ task: AgentTask) -> AgentStatus {
        task.effectiveStatus(now: Date(), threshold: staleTimeoutStore.threshold())
    }
```

`staleTasks`(`:27`)与 `items`(`:31`)改为:
```swift
    private var staleTasks: [AgentTask] {
        tasks.filter { !$0.isArchived && effective($0) == .stale }
    }

    private var items: [HistoryItemData] {
        let archivedTasks = tasks
            .filter { effective($0).isTerminal || $0.isArchived || effective($0) == .stale }
            .map { HistoryItemData.fromTask($0, status: effective($0)) }
        let inboxRows = inboxItems.map(HistoryItemData.fromInboxItem)
        let merged = (archivedTasks + inboxRows)
            .filter(filter.matches)
            .sorted { $0.updatedAt > $1.updatedAt }
        return merged
    }
```
(`staleTaskRow` 硬编码 `[ STALE ]` badge、`staleCodeLine` 只读 `updatedAt`,均无需改。)

- [ ] **Step 7: 生成工程 + 编译**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodegen generate >/dev/null 2>&1
xcodebuild -project BarkMate.xcodeproj -scheme BarkMate -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 8: 既有 Dashboard/History UI 测试不回归**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodebuild test -project BarkMate.xcodeproj -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:BarkMateUITests/BarkMateFunctionalSmokeTests/testHistoryFiltersSeededTimelineItems \
  -only-testing:BarkMateUITests/BarkMateFunctionalSmokeTests/testSettingsContentCanScrollThroughAllSections 2>&1 | grep -iE "Test Case.*(passed|failed)|error:" | head
```
Expected: 两个既有测试均 `passed`。

- [ ] **Step 9: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/App/Sources/Views/AgentDashboardView.swift BarkMate/App/Sources/Views/HistoryView.swift
git commit -m "feat: derive stale status via effectiveStatus in dashboard + history"
```

---

### Task 6: Settings 行可点击 + StaleTimeoutPickerView

**Files:**
- Modify: `BarkMate/App/Sources/Views/SettingsView.swift`
- Create: `BarkMate/App/Sources/Views/StaleTimeoutPickerView.swift`
- Test: `BarkMate/App/UITests/BarkMateUITests/BarkMateFunctionalSmokeTests.swift`(新增一个方法)

**Interfaces:**
- Consumes: `Container.shared.staleTimeoutStore()`(Task 4);`StaleThreshold` / `StaleThresholdCatalog`(Task 1);现有 `MCConsoleHeader / MCSectionHeader / MCSettingRow / MCSettingValue`。
- Produces: 可点击 Stale timeout 行(a11y id `settings-stale-timeout`);`StaleTimeoutPickerView`;声音档行(a11y id `stale-option-<label>`,label 用无空格形式如 `30min`/`off`)。

- [ ] **Step 1: Write the failing UI test**

在 `BarkMate/App/UITests/BarkMateUITests/BarkMateFunctionalSmokeTests.swift` 新增(置于 `testAlertSoundPickerOpensAndSelects` 之后):
```swift
    func testStaleTimeoutPickerOpensAndSelects() {
        launchApp()

        app.buttons["tab-settings"].tap()

        let row = app.buttons["settings-stale-timeout"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
        row.tap()

        let option = app.buttons["stale-option-60min"]
        XCTAssertTrue(option.waitForExistence(timeout: 5), app.debugDescription)
        option.tap()

        XCTAssertTrue(option.isSelected, app.debugDescription)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodebuild test -project BarkMate.xcodeproj -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:BarkMateUITests/BarkMateFunctionalSmokeTests/testStaleTimeoutPickerOpensAndSelects 2>&1 | grep -iE "Test Case.*(passed|failed)|error:" | head
```
Expected: FAIL —— `settings-stale-timeout` 找不到(当前是裸行)。

- [ ] **Step 3: 改 SettingsView 的 Stale timeout 行**

Modify `BarkMate/App/Sources/Views/SettingsView.swift`。

在 `@State private var showSoundPicker` 之后新增:
```swift
    @State private var showStalePicker: Bool = false
    @Injected(\.staleTimeoutStore) private var staleTimeoutStore: StaleTimeoutStore
```

把 Stale timeout 行(当前 `:67-69` 附近,裸 `MCSettingRow(title: "Stale timeout"...)`)替换为:
```swift
                    Button { showStalePicker = true } label: {
                        MCSettingRow(
                            title: "Stale timeout",
                            detail: "Running > this window → auto-demote to History · Stale."
                        ) { MCSettingValue(staleTimeoutStore.threshold().displayLabel) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-stale-timeout")
```

在 `navigationDestination(isPresented: $showSoundPicker)` 之后新增:
```swift
        .navigationDestination(isPresented: $showStalePicker) {
            StaleTimeoutPickerView()
        }
```

- [ ] **Step 4: 写 StaleTimeoutPickerView**

Create `BarkMate/App/Sources/Views/StaleTimeoutPickerView.swift`:
```swift
//
//  StaleTimeoutPickerView.swift
//  BarkAgent
//
//  Stale timeout 阈值选择屏。单栏档位,点击 = 选中 + 持久化。
//

import SwiftUI
import Factory
import Models
import Store
import DesignSystem

struct StaleTimeoutPickerView: View {

    @Injected(\.staleTimeoutStore) private var store: StaleTimeoutStore

    @State private var selected: StaleThreshold = StaleThresholdCatalog.defaultThreshold

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["SYS", "SETTINGS", "STALE"],
                    title: "Stale timeout"
                )
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 0) {
                    MCSectionHeader("Threshold", trailing: "running → stale")
                    ForEach(StaleThresholdCatalog.options, id: \.self) { option in
                        optionRow(option)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("stale-timeout-picker")
        .onAppear { selected = store.threshold() }
    }

    private func optionRow(_ option: StaleThreshold) -> some View {
        Button {
            store.setThreshold(option)
            selected = option
        } label: {
            MCSettingRow(title: option.displayLabel) {
                MCSettingValue(selected == option ? "✓" : "", tone: .accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stale-option-\(identifier(option))")
        .accessibilityAddTraits(selected == option ? [.isSelected] : [])
    }

    /// a11y id 用无空格形式:off / 10min / 30min ...
    private func identifier(_ option: StaleThreshold) -> String {
        switch option {
        case .off: return "off"
        case .minutes(let m): return "\(m)min"
        }
    }
}
```

`StaleThreshold` 需可用于 `ForEach(id: \.self)` —— 已在 Task 1 声明为 `Hashable`(`off`/`minutes(Int)` 自动合成)。无需额外改动。

- [ ] **Step 5: 生成工程 + 编译**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodegen generate >/dev/null 2>&1
xcodebuild -project BarkMate.xcodeproj -scheme BarkMate -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -4
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 6: Run UI test to verify it passes**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodebuild test -project BarkMate.xcodeproj -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:BarkMateUITests/BarkMateFunctionalSmokeTests/testStaleTimeoutPickerOpensAndSelects 2>&1 | grep -iE "Test Case.*(passed|failed)|error:" | head
```
Expected: `Test Case ... passed`。

- [ ] **Step 7: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/App/Sources/Views/SettingsView.swift BarkMate/App/Sources/Views/StaleTimeoutPickerView.swift BarkMate/App/UITests/BarkMateUITests/BarkMateFunctionalSmokeTests.swift
git commit -m "feat: stale timeout picker with threshold selection"
```

---

### Task 7: 全量回归 + 真机验证

**Files:** 无(验证任务)

**Interfaces:**
- Consumes: Task 1–6 全部产物。
- Produces: 通过标准的可发布功能。

- [ ] **Step 1: 全包单测**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate/Packages/Models && swift test 2>&1 | tail -3
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate/Packages/Store && swift test 2>&1 | tail -3
```
Expected: 两个包全绿,无既有测试回归。

- [ ] **Step 2: App 单测 + UI 测试全量**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodebuild test -project BarkMate.xcodeproj -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | grep -iE "Test Suite '.*' (passed|failed)|Executed [0-9]+ tests|\*\* TEST" | tail -30
```
Expected: 新增测试全绿。注意:`BarkMateScreenshotRegressionTests` 的 2 项与 `testSeededAgentDetailSupportsPrimaryActions` 是**先前 WIP 的既有失败**(见 memory `preexisting-ui-test-failures`),非本功能回归 —— 但需确认本功能未引入**新**失败:Dashboard/History 派生改造后,若 settings-default 截图因 Stale timeout 行值文案变化(`30 MIN` 保持不变,应无新增差异)导致新差异,需人工核对 diff 归因。

- [ ] **Step 3: 真机验证清单(手动,对照 spec 验收标准)**

1. Settings → 点 "Stale timeout" → 进入档位选择屏。
2. 点 60 min → 持久化;杀进程重开保留;Settings 行显示 `60 min`。
3. 制造一个 `updatedAt` 早于阈值的 running task(可用 Dashboard 的 demo push 后等待,或改 seed),确认 Dashboard 显示 `[STALE]`、History 顶部 STALE 段出现、stale 计数 +1。
4. 未超时 running 仍 running;done/failed 不受影响。
5. 阈值设 Off → 任何 running 都不会变 stale。

- [ ] **Step 4: 收尾提交(若真机验证产生微调)**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add -A && git commit -m "test: verify stale timeout end-to-end"
```

---

## Self-Review

**1. Spec coverage:**
- StaleThreshold + Catalog → Task 1 ✓
- effectiveStatus 派生纯函数 → Task 2 ✓
- StaleTimeoutStore 持久化 + 默认/Off 哨兵 → Task 3 ✓
- DI 注册 → Task 4 ✓
- 全面消费点改造(Dashboard counts/buckets/prioritySort/historyPreview + History staleTasks/items)→ Task 5 ✓
- Settings 可点击行 + Picker → Task 6 ✓
- 四类测试(StaleThreshold/EffectiveStatus/StaleTimeoutStore/UI smoke)→ Task 1/2/3/6 ✓
- 验收标准真机项 → Task 7 ✓

**2. Placeholder scan:** 无 TBD/TODO;所有代码步骤含完整代码。Task 5 Step 5/6 要求先读 prioritySort/HistoryView 现场行号确认(已在写计划时核对:prioritySort `:376` 读 `status.sortPriority`,staleCodeLine 不读 status)。

**3. Type consistency:**
- `StaleThreshold`(`.off`/`.minutes`)、`.seconds`/`.displayLabel`、`StaleThresholdCatalog.options`/`.defaultThreshold` 全任务一致。Task 6 需要 `Hashable`,已在 Task 6 Step 4 指明回补 Task 1 声明。
- `AgentTask.effectiveStatus(now:threshold:)` 在 Task 2 定义,Task 5 调用签名一致。
- `StaleTimeoutStore.setThreshold(_:)`/`threshold()`/`init(defaults:)` 在 Task 3 定义,Task 4/5/6 调用一致。
- `AgentCardData.fromTask(_:status:)` 与 `HistoryItemData.fromTask(_:status:)` 新签名在 Task 5 Step 1/2 定义,Step 4/5/6 调用一致。
