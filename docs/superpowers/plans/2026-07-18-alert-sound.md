# Alert Sound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Settings 的 "Alert sound" 行可点击,进入 per-status 声音选择屏,可即时试听并持久化,APNs 推送到达时按所选声音播报。

**Architecture:** 三层复用现有 App Group 通道 —— App 侧 `AlertSoundPickerView` 写入 `AlertSoundStore`(共享 `UserDefaults`),NSE 侧 `NotificationService` 读同一 store 覆写 `content.sound`。声音 `.caf` 来自 Bark 官方(MIT),同时打进 App 与 NSE 两个 target 的 bundle 根目录。

**Tech Stack:** Swift 6 / SwiftUI / SwiftData / Factory DI / XcodeGen / XCTest / AVFoundation(试听)/ UserNotifications(NSE)。

## Global Constraints

- 平台 iOS 18.0+;Swift 6.0(Store/BarkService 包)/ 5.10(App 编译);`SWIFT_STRICT_CONCURRENCY: complete`。
- App Group identifier 固定 `group.com.barkagent.shared`(`Store/AppGroup.swift:25`,已在两 target entitlement 配置)。
- 声音 `.caf` 必须位于各 target **main bundle 根目录**(`UNNotificationSound(named:)` 仅识别根目录),不能只放 SPM 包。
- 存储值为声音 **id 字符串**(如 `"bell"`),经 `SoundCatalog` 映射到文件名,不散落 `.caf` 扩展名。
- 新类型放 `Store` 包(App 与 NSE 均已依赖,不新增依赖)。
- Per-status 可覆盖的 status 仅三个:`waiting_input / blocked / failed`;`running / done / stale` 用全局默认。
- 回落链:`alertSound.<status>` → `alertSound.default` → 系统默认(不覆盖)。
- **仅当用户主动配置过**才覆写 `content.sound`;未配置保持发送方原声(对老用户零副作用)。
- 声音资源 MIT 归属:`Shared/Sounds/LICENSE-sounds.md`。
- key 前缀 `alertSound.`;特殊档 `.systemDefault`(不写文件)与 `.silence`(用 `silence.caf`)。
- 测试注入自定义 `UserDefaults(suiteName:)`,tearDown 用 `removePersistentDomain`(见 `DeviceTokenStoreTests`)。

---

### Task 1: 引入 Bark 官方声音资源 + XcodeGen 集成

**Files:**
- Create: `BarkMate/Shared/Sounds/*.caf`(33 个文件)
- Create: `BarkMate/Shared/Sounds/LICENSE-sounds.md`
- Modify: `BarkMate/project.yml`(App target `sources` 与 NSE target `sources` 各加一条)

**Interfaces:**
- Consumes: 无
- Produces: App bundle 与 NSE bundle 根目录含 `alarm.caf ... update.caf`(33 个,含 `silence.caf`);后续 Task 4 试听、Task 5 NSE 引用这些文件名。

- [ ] **Step 1: 拉取 Bark 官方声音到项目目录**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
mkdir -p Shared/Sounds
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/Finb/Bark.git "$tmp/bark"
cp "$tmp/bark/Sounds/"*.caf Shared/Sounds/
rm -rf "$tmp"
ls Shared/Sounds/*.caf | wc -l
```
Expected: `33`(若上游有增减,以实际为准,但必须包含 `silence.caf`)。

- [ ] **Step 2: 验证 silence.caf 存在**

Run: `ls BarkMate/Shared/Sounds/silence.caf`
Expected: 路径存在,无 "No such file"。

- [ ] **Step 3: 写许可归属文件**

Create `BarkMate/Shared/Sounds/LICENSE-sounds.md`:
```markdown
# 声音资源来源

本目录 `.caf` 声音文件取自 Bark 开源项目:
https://github.com/Finb/Bark (Sounds/)

Bark 以 MIT License 授权。原始版权归 Bark 作者所有。
本项目仅原样引入用于通知声音,未作修改。
```

- [ ] **Step 4: 在 project.yml 给两个 target 加资源路径**

Modify `BarkMate/project.yml`。App target(`BarkMate`,当前 `sources` 见 `:54-56`)改为:
```yaml
    sources:
      - path: App/Sources
      - path: App/Resources
      - path: Shared/Sounds
```
NSE target(`NotificationServiceExtension`,当前 `sources` 见 `:112-113`)改为:
```yaml
    sources:
      - path: NotificationServiceExtension/Sources
      - path: Shared/Sounds
```

- [ ] **Step 5: 重新生成工程并确认资源进入两个 target**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodegen generate
grep -c "bell.caf" BarkMate.xcodeproj/project.pbxproj
```
Expected: `grep -c` 返回 ≥ 2(App 与 NSE 各一次 build file 引用)。

- [ ] **Step 6: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/Shared/Sounds BarkMate/project.yml BarkMate/BarkMate.xcodeproj
git commit -m "feat: bundle Bark alert sounds into app + NSE targets"
```

---

### Task 2: SoundCatalog(声音清单值类型)

**Files:**
- Create: `BarkMate/Packages/Store/Sources/Store/SoundCatalog.swift`
- Test: `BarkMate/Packages/Store/Tests/StoreTests/SoundCatalogTests.swift`

**Interfaces:**
- Consumes: 无
- Produces:
  - `struct AlertSound: Identifiable, Hashable, Sendable`,字段 `id: String`、`displayName: String`、`fileName: String`。
  - `enum SoundCatalog`:
    - `static let systemDefaultID = "__system__"`
    - `static let silenceID = "silence"`
    - `static let barkSounds: [AlertSound]`(33 项真实声音,`silence` 也在内)
    - `static let all: [AlertSound]`(= `[systemDefault] + barkSounds`,`systemDefault` 是伪项 id=`__system__` fileName="")
    - `static func sound(for id: String) -> AlertSound?`
    - `static let systemDefault: AlertSound`(id=`__system__`, displayName="System default", fileName="")

- [ ] **Step 1: Write the failing test**

Create `BarkMate/Packages/Store/Tests/StoreTests/SoundCatalogTests.swift`:
```swift
import XCTest
@testable import Store

final class SoundCatalogTests: XCTestCase {

    func testBarkSoundsCountAndSilencePresent() {
        XCTAssertEqual(SoundCatalog.barkSounds.count, 33)
        XCTAssertTrue(SoundCatalog.barkSounds.contains { $0.id == "silence" })
    }

    func testAllIncludesSystemDefaultFirst() {
        XCTAssertEqual(SoundCatalog.all.first?.id, SoundCatalog.systemDefaultID)
        XCTAssertEqual(SoundCatalog.all.count, SoundCatalog.barkSounds.count + 1)
    }

    func testIDsAreUnique() {
        let ids = SoundCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testFileNameMapping() {
        XCTAssertEqual(SoundCatalog.sound(for: "bell")?.fileName, "bell.caf")
        XCTAssertEqual(SoundCatalog.sound(for: "silence")?.fileName, "silence.caf")
    }

    func testSystemDefaultHasEmptyFileName() {
        XCTAssertEqual(SoundCatalog.sound(for: SoundCatalog.systemDefaultID)?.fileName, "")
    }

    func testUnknownIDReturnsNil() {
        XCTAssertNil(SoundCatalog.sound(for: "does-not-exist"))
    }

    func testDisplayNameIsCapitalized() {
        XCTAssertEqual(SoundCatalog.sound(for: "bell")?.displayName, "Bell")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BarkMate/Packages/Store && swift test --filter SoundCatalogTests`
Expected: FAIL,编译错误 "cannot find 'SoundCatalog' in scope"。

- [ ] **Step 3: Write minimal implementation**

Create `BarkMate/Packages/Store/Sources/Store/SoundCatalog.swift`:
```swift
//
//  SoundCatalog.swift
//  Store
//
//  Bark 官方声音清单(静态硬编码)。App 试听与 NSE 推送共享同一份 id↔文件名映射。
//  文件本体位于各 target main bundle 根目录(见 Shared/Sounds + project.yml)。
//

import Foundation

public struct AlertSound: Identifiable, Hashable, Sendable {
    public let id: String           // e.g. "bell";系统默认为 "__system__"
    public let displayName: String  // e.g. "Bell"
    public let fileName: String     // e.g. "bell.caf";系统默认为 ""

    public init(id: String, displayName: String, fileName: String) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
    }
}

public enum SoundCatalog {

    /// 伪 id:表示"用系统默认/不覆盖发送方声音"。
    public static let systemDefaultID = "__system__"
    /// 到达但不响。
    public static let silenceID = "silence"

    public static let systemDefault = AlertSound(
        id: systemDefaultID, displayName: "System default", fileName: ""
    )

    /// Bark 官方 33 个声音的 id(= 文件名去扩展名)。
    private static let barkIDs = [
        "alarm", "anticipate", "bell", "birdsong", "bloom", "calypso", "chime",
        "choo", "descent", "electronic", "fanfare", "glass", "gotosleep",
        "healthnotification", "horn", "ladder", "mailsent", "minuet",
        "multiwayinvitation", "newmail", "newsflash", "noir", "paymentsuccess",
        "shake", "sherwoodforest", "silence", "spell", "suspense", "telegraph",
        "tiptoes", "typewriters", "update"
    ]

    public static let barkSounds: [AlertSound] = barkIDs.map { id in
        AlertSound(id: id, displayName: displayName(for: id), fileName: "\(id).caf")
    }

    /// 展示用清单:系统默认置顶,其后为全部 Bark 声音。
    public static let all: [AlertSound] = [systemDefault] + barkSounds

    public static func sound(for id: String) -> AlertSound? {
        all.first { $0.id == id }
    }

    /// id → 展示名。特殊拼写单独处理,其余首字母大写。
    private static func displayName(for id: String) -> String {
        switch id {
        case "healthnotification": return "Health notification"
        case "multiwayinvitation": return "Multiway invitation"
        case "paymentsuccess": return "Payment success"
        case "sherwoodforest": return "Sherwood forest"
        case "gotosleep": return "Go to sleep"
        case "newmail": return "New mail"
        case "mailsent": return "Mail sent"
        case "newsflash": return "News flash"
        default: return id.prefix(1).uppercased() + id.dropFirst()
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BarkMate/Packages/Store && swift test --filter SoundCatalogTests`
Expected: PASS(7 tests)。若 Task 1 上游声音数不是 33,同步修正 `barkIDs` 与测试断言。

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/Packages/Store/Sources/Store/SoundCatalog.swift BarkMate/Packages/Store/Tests/StoreTests/SoundCatalogTests.swift
git commit -m "feat: add SoundCatalog with Bark sound inventory"
```

---

### Task 3: AlertSoundStore(per-status 持久化 + 回落链)

**Files:**
- Create: `BarkMate/Packages/Store/Sources/Store/AlertSoundStore.swift`
- Test: `BarkMate/Packages/Store/Tests/StoreTests/AlertSoundStoreTests.swift`

**Interfaces:**
- Consumes: `SoundCatalog`(Task 2);`AppGroup.userDefaults`(`Store/AppGroup.swift:48`);`Models.AgentStatus`。
- Produces:
  - `struct AlertSoundStore: Sendable`
  - `init(defaults: UserDefaults? = nil)`(nil → `AppGroup.userDefaults`)
  - `func setGlobalDefault(id: String)` / `func globalDefaultID() -> String?`
  - `func setOverride(id: String?, for status: AgentStatus)`(id=nil 清除该 status override)
  - `func overrideID(for status: AgentStatus) -> String?`
  - `func resolvedSoundID(for status: AgentStatus) -> String?`(回落链;全无配置返回 nil)
  - `static let overridableStatuses: [AgentStatus]`(= `[.waitingInput, .blocked, .failed]`)

- [ ] **Step 1: Write the failing test**

Create `BarkMate/Packages/Store/Tests/StoreTests/AlertSoundStoreTests.swift`:
```swift
import XCTest
import Models
@testable import Store

final class AlertSoundStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: AlertSoundStore!

    override func setUpWithError() throws {
        suiteName = "AlertSoundStoreTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        self.defaults = defaults
        store = AlertSoundStore(defaults: defaults)
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        store = nil; defaults = nil; suiteName = nil
    }

    func testEmptyResolvesToNil() {
        XCTAssertNil(store.resolvedSoundID(for: .failed))
        XCTAssertNil(store.globalDefaultID())
    }

    func testGlobalDefaultRoundTrip() {
        store.setGlobalDefault(id: "bell")
        XCTAssertEqual(store.globalDefaultID(), "bell")
    }

    func testResolveFallsBackToGlobalDefault() {
        store.setGlobalDefault(id: "chime")
        XCTAssertEqual(store.resolvedSoundID(for: .blocked), "chime")
    }

    func testPerStatusOverrideWinsOverGlobal() {
        store.setGlobalDefault(id: "chime")
        store.setOverride(id: "alarm", for: .failed)
        XCTAssertEqual(store.resolvedSoundID(for: .failed), "alarm")
        XCTAssertEqual(store.resolvedSoundID(for: .blocked), "chime")
    }

    func testClearOverrideFallsBackToGlobal() {
        store.setGlobalDefault(id: "chime")
        store.setOverride(id: "alarm", for: .failed)
        store.setOverride(id: nil, for: .failed)
        XCTAssertNil(store.overrideID(for: .failed))
        XCTAssertEqual(store.resolvedSoundID(for: .failed), "chime")
    }

    func testOverridableStatuses() {
        XCTAssertEqual(
            AlertSoundStore.overridableStatuses,
            [.waitingInput, .blocked, .failed]
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BarkMate/Packages/Store && swift test --filter AlertSoundStoreTests`
Expected: FAIL,"cannot find 'AlertSoundStore' in scope"。

- [ ] **Step 3: Write minimal implementation**

Create `BarkMate/Packages/Store/Sources/Store/AlertSoundStore.swift`:
```swift
//
//  AlertSoundStore.swift
//  Store
//
//  Per-status 声音偏好,存 App Group 共享 UserDefaults。App 写、NSE 读。
//  存声音 id 字符串(如 "bell"),不存文件名。
//

import Foundation
import Models

public struct AlertSoundStore: @unchecked Sendable {

    /// 可单独覆盖的 status;其余用全局默认。
    public static let overridableStatuses: [AgentStatus] = [
        .waitingInput, .blocked, .failed
    ]

    private static let keyPrefix = "alertSound."
    private static let defaultKey = keyPrefix + "default"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? AppGroup.userDefaults
    }

    // MARK: - 全局默认

    public func setGlobalDefault(id: String) {
        defaults.set(id, forKey: Self.defaultKey)
    }

    public func globalDefaultID() -> String? {
        defaults.string(forKey: Self.defaultKey)
    }

    // MARK: - Per-status override

    public func setOverride(id: String?, for status: AgentStatus) {
        let key = Self.keyPrefix + status.rawValue
        if let id {
            defaults.set(id, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func overrideID(for status: AgentStatus) -> String? {
        defaults.string(forKey: Self.keyPrefix + status.rawValue)
    }

    // MARK: - 解析(回落链)

    /// status override → 全局默认 → nil(nil 表示不覆盖发送方声音)。
    public func resolvedSoundID(for status: AgentStatus) -> String? {
        overrideID(for: status) ?? globalDefaultID()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BarkMate/Packages/Store && swift test --filter AlertSoundStoreTests`
Expected: PASS(6 tests)。

- [ ] **Step 5: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/Packages/Store/Sources/Store/AlertSoundStore.swift BarkMate/Packages/Store/Tests/StoreTests/AlertSoundStoreTests.swift
git commit -m "feat: add AlertSoundStore with per-status fallback"
```

---

### Task 4: SoundPreviewPlayer(App 内试听器)

**Files:**
- Create: `BarkMate/App/Sources/SoundPreviewPlayer.swift`

**Interfaces:**
- Consumes: `SoundCatalog`(Task 2)的 `fileName`;bundle 内 `.caf`(Task 1)。
- Produces:
  - `final class SoundPreviewPlayer`(`@MainActor`)
  - `static let shared: SoundPreviewPlayer`
  - `func play(fileName: String)`(空串或 `silence.caf` 不播放;播放前切上一条)

**注:** 试听依赖音频硬件,不做单测(见 spec 测试策略);正确性靠 Task 8 真机验证。此任务无 test 步骤,仅实现 + 编译。

- [ ] **Step 1: Write implementation**

Create `BarkMate/App/Sources/SoundPreviewPlayer.swift`:
```swift
//
//  SoundPreviewPlayer.swift
//  BarkAgent
//
//  声音选择屏的即时试听。用 AVAudioPlayer 播放 bundle 内 .caf。
//  设 .playback category,使真机静音开关下试听仍出声。
//

import AVFoundation
import os

@MainActor
final class SoundPreviewPlayer {

    static let shared = SoundPreviewPlayer()

    private static let log = Logger(subsystem: "com.barkagent.ios", category: "sound-preview")

    private var player: AVAudioPlayer?

    private init() {}

    /// 播放指定 .caf。空文件名(系统默认)不播;silence 不播。
    func play(fileName: String) {
        guard !fileName.isEmpty, fileName != "silence.caf" else {
            player?.stop()
            return
        }
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            Self.log.error("preview sound not found in bundle: \(fileName, privacy: .public)")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player?.stop()
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
        } catch {
            Self.log.error("preview playback failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
```

- [ ] **Step 2: 验证编译(全项目 build 在 Task 6/7 一并跑)**

此文件依赖仅 AVFoundation + os,无需其它任务。可暂缓单独 build,留待 Task 6 首次 App target 编译时一并校验。

- [ ] **Step 3: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/App/Sources/SoundPreviewPlayer.swift
git commit -m "feat: add SoundPreviewPlayer for in-app sound preview"
```

---

### Task 5: NSE 推送生效(applyAlertSound)

**Files:**
- Modify: `BarkMate/NotificationServiceExtension/Sources/NotificationService.swift`
- Test: `BarkMate/Packages/BarkService/Tests/BarkServiceTests/AlertSoundResolutionTests.swift`
- Create(被测纯函数): `BarkMate/Packages/BarkService/Sources/BarkService/AlertSoundResolver.swift`

**Interfaces:**
- Consumes: `PushParser.parse(userInfo:)`(`BarkService/PushParser.swift:84`)得 `agentStatus`;`AlertSoundStore.resolvedSoundID(for:)`(Task 3);`SoundCatalog.sound(for:)`(Task 2)。
- Produces:
  - `enum AlertSoundResolver`
  - `enum SoundDecision: Equatable { case keep; case silence; case named(String) }`
    - `keep` = 不覆盖发送方声音;`silence` = `content.sound = nil`;`named(x)` = `UNNotificationSound(named: x)`
  - `static func decide(userInfo:defaults:) -> SoundDecision`(用纯 store 逻辑,便于测试)

理由:把决策抽成 BarkService 里的纯函数,可脱离 NSE runtime 单测;NSE 只负责把 `SoundDecision` 落到 `content.sound`。

- [ ] **Step 1: Write the failing test**

Create `BarkMate/Packages/BarkService/Tests/BarkServiceTests/AlertSoundResolutionTests.swift`:
```swift
import XCTest
import Store
@testable import BarkService

final class AlertSoundResolutionTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "AlertSoundResolutionTests-\(UUID().uuidString)"
        guard let d = UserDefaults(suiteName: suiteName) else {
            throw XCTSkip("Cannot create UserDefaults suite")
        }
        defaults = d
    }

    override func tearDownWithError() throws {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil; suiteName = nil
    }

    private func userInfo(status: String?) -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = ["aps": ["alert": ["body": "hi"]]]
        if let status { info["agent_status"] = status }
        return info
    }

    func testUnconfiguredKeepsSenderSound() {
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "failed"), defaults: defaults
        )
        XCTAssertEqual(decision, .keep)
    }

    func testNoStatusKeepsSenderSound() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: "bell")
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: nil), defaults: defaults
        )
        XCTAssertEqual(decision, .keep)
    }

    func testGlobalDefaultAppliesNamedSound() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: "bell")
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "blocked"), defaults: defaults
        )
        XCTAssertEqual(decision, .named("bell.caf"))
    }

    func testPerStatusOverride() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: "bell")
        store.setOverride(id: "alarm", for: .failed)
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "failed"), defaults: defaults
        )
        XCTAssertEqual(decision, .named("alarm.caf"))
    }

    func testSilenceDecision() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: "silence")
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "blocked"), defaults: defaults
        )
        XCTAssertEqual(decision, .silence)
    }

    func testSystemDefaultKeepsSenderSound() {
        let store = AlertSoundStore(defaults: defaults)
        store.setGlobalDefault(id: SoundCatalog.systemDefaultID)
        let decision = AlertSoundResolver.decide(
            userInfo: userInfo(status: "blocked"), defaults: defaults
        )
        XCTAssertEqual(decision, .keep)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd BarkMate/Packages/BarkService && swift test --filter AlertSoundResolutionTests`
Expected: FAIL,"cannot find 'AlertSoundResolver'"。(注:BarkService 需依赖 Store,见 Step 3。)

- [ ] **Step 3: 确认 BarkService 依赖 Store,并写实现**

先检查 `BarkMate/Packages/BarkService/Package.swift` 是否含 `Store` 依赖;若无,给 `BarkService` target 的 `dependencies` 加 `.product(name: "Store", package: "Store")` 并在 `dependencies:` 顶部加 `.package(path: "../Store")`。

Create `BarkMate/Packages/BarkService/Sources/BarkService/AlertSoundResolver.swift`:
```swift
//
//  AlertSoundResolver.swift
//  BarkService
//
//  纯决策函数:给定 APNs userInfo + 声音偏好,决定 NSE 该如何设置 content.sound。
//  抽成纯函数以便脱离 UNNotification runtime 单测。
//

import Foundation
import Store

public enum SoundDecision: Equatable, Sendable {
    case keep               // 不覆盖发送方声音
    case silence            // content.sound = nil
    case named(String)      // UNNotificationSound(named: fileName)
}

public enum AlertSoundResolver {

    public static func decide(
        userInfo: [AnyHashable: Any],
        defaults: UserDefaults? = nil
    ) -> SoundDecision {
        let parsed = PushParser.parse(userInfo: userInfo)
        guard let status = parsed.agentStatus else { return .keep }

        let store = AlertSoundStore(defaults: defaults)
        guard let id = store.resolvedSoundID(for: status) else { return .keep }
        guard id != SoundCatalog.systemDefaultID else { return .keep }
        guard let sound = SoundCatalog.sound(for: id) else { return .keep }

        if sound.id == SoundCatalog.silenceID { return .silence }
        return .named(sound.fileName)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd BarkMate/Packages/BarkService && swift test --filter AlertSoundResolutionTests`
Expected: PASS(6 tests)。

- [ ] **Step 5: 在 NSE 落地 SoundDecision**

Modify `BarkMate/NotificationServiceExtension/Sources/NotificationService.swift`。在 `processPipeline`(`:48-73`)中 `applyDecrypted` 之后加一行,并新增私有方法:

在 `applyDecrypted(content: content, from: outcome.decryptResult)` 之后插入:
```swift
        applyAlertSound(content: content, from: outcome.decryptResult)
```

在 `applyDecrypted` 方法之后新增:
```swift
    /// 按用户 per-status 声音偏好覆写 content.sound。未配置则不动(保留发送方声音)。
    private func applyAlertSound(
        content: UNMutableNotificationContent,
        from result: DecryptProcessor.DecryptResult
    ) {
        switch AlertSoundResolver.decide(userInfo: result.userInfo) {
        case .keep:
            break
        case .silence:
            content.sound = nil
        case .named(let fileName):
            content.sound = UNNotificationSound(named: UNNotificationSoundName(fileName))
        }
    }
```

- [ ] **Step 6: 生成工程并编译 NSE target**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodegen generate
xcodebuild -project BarkMate.xcodeproj -scheme BarkMate -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 7: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/Packages/BarkService BarkMate/NotificationServiceExtension/Sources/NotificationService.swift
git commit -m "feat: apply per-status alert sound in notification service"
```

---

### Task 6: DI 注册 AlertSoundStore(App + NSE)

**Files:**
- Modify: `BarkMate/App/Sources/DI/Container+App.swift`
- Modify: `BarkMate/NotificationServiceExtension/Sources/DI/Container+Extension.swift`

**Interfaces:**
- Consumes: `AlertSoundStore`(Task 3);测试注入沿用 `ProcessInfo.barkAgentTestDefaults`(`Container+App.swift:145`)。
- Produces: `Container.shared.alertSoundStore() -> AlertSoundStore`,供 Task 7 的 SettingsView / Picker 用。

**注:** NSE 侧 `AlertSoundResolver.decide` 自建 store(默认 `AppGroup.userDefaults`),NSE DI 注册可选;为一致性也注册。

- [ ] **Step 1: App 侧注册**

Modify `BarkMate/App/Sources/DI/Container+App.swift`,在 `deviceTokenStore`(`:70-80`)之后新增:
```swift
    /// Per-status 声音偏好存储(共享 UserDefaults)。
    var alertSoundStore: Factory<AlertSoundStore> {
        self {
            AlertSoundStore(defaults: ProcessInfo.processInfo.barkAgentTestDefaults)
        }
        .singleton
    }
```

- [ ] **Step 2: NSE 侧注册**

Modify `BarkMate/NotificationServiceExtension/Sources/DI/Container+Extension.swift`,在 `keychainConfiguration` 之后新增:
```swift
    /// Per-status 声音偏好(共享 UserDefaults)。
    var alertSoundStore: Factory<AlertSoundStore> {
        self { AlertSoundStore() }
            .singleton
    }
```

- [ ] **Step 3: 编译校验**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodebuild -project BarkMate.xcodeproj -scheme BarkMate -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 4: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/App/Sources/DI/Container+App.swift BarkMate/NotificationServiceExtension/Sources/DI/Container+Extension.swift
git commit -m "feat: register AlertSoundStore in App + NSE DI"
```

---

### Task 7: SettingsView 可点击行 + AlertSoundPickerView

**Files:**
- Modify: `BarkMate/App/Sources/Views/SettingsView.swift`
- Create: `BarkMate/App/Sources/Views/AlertSoundPickerView.swift`
- Test: `BarkMate/App/UITests/BarkMateUITests/BarkMateFunctionalSmokeTests.swift`(新增一个 UI smoke test 方法)

**Interfaces:**
- Consumes: `Container.shared.alertSoundStore()`(Task 6);`SoundCatalog`(Task 2);`SoundPreviewPlayer.shared`(Task 4);现有 `MCConsoleHeader / MCSectionHeader / MCSettingRow / MCSettingValue / MissionControl.Color`。
- Produces: 可点击 Alert sound 行(a11y id `settings-alert-sound`)、`AlertSoundPickerView`(a11y id `alert-sound-picker`)、声音行(a11y id `sound-row-<id>`)。

- [ ] **Step 1: Write the failing UI test**

在 `BarkMate/App/UITests/BarkMateUITests/BarkMateFunctionalSmokeTests.swift` 新增(置于合适的既有 Settings 相关分组内):
```swift
    func testAlertSoundPickerOpensAndSelects() {
        let app = launchApp()  // 复用文件内既有启动 helper;若名称不同,用现有 Settings 用例同款启动方式
        navigateToSettingsTab(app) // 复用既有导航 helper;若无则用现有 Settings 用例同款方式打开 Settings

        let row = app.buttons["settings-alert-sound"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let picker = app.otherElements["alert-sound-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        let bell = app.buttons["sound-row-bell"]
        XCTAssertTrue(bell.waitForExistence(timeout: 5))
        bell.tap()
        // 选中态:该行 isSelected 或含勾选标记文案
        XCTAssertTrue(bell.isSelected || app.staticTexts["sound-selected-bell"].exists)
    }
```
(实现前先在文件内确认既有 helper 的真实名字:`launchApp` / `navigateToSettingsTab` 是否存在;如命名不同,替换为既有等价 helper。)

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodebuild test -project BarkMate.xcodeproj -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:BarkMateUITests/BarkMateFunctionalSmokeTests/testAlertSoundPickerOpensAndSelects 2>&1 | tail -15
```
Expected: FAIL —— `settings-alert-sound` 找不到(当前是裸行,非 button)。

- [ ] **Step 3: 改 SettingsView 的 Alert sound 行**

Modify `BarkMate/App/Sources/Views/SettingsView.swift`:

在 `@State private var showServerList` 附近新增:
```swift
    @State private var showSoundPicker: Bool = false
    @Injected(\.alertSoundStore) private var alertSoundStore: AlertSoundStore
```

把 `:78-81` 的 Alert sound 行替换为:
```swift
                    Button { showSoundPicker = true } label: {
                        MCSettingRow(
                            title: "Alert sound",
                            detail: "Per-status override · default = system."
                        ) { MCSettingValue(globalSoundLabel) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-alert-sound")
```

在 `navigationDestination(isPresented: $showServerList)` 之后加:
```swift
        .navigationDestination(isPresented: $showSoundPicker) {
            AlertSoundPickerView()
        }
```

在 `tokenPreview` 附近新增计算属性:
```swift
    private var globalSoundLabel: String {
        guard
            let id = alertSoundStore.globalDefaultID(),
            let sound = SoundCatalog.sound(for: id)
        else { return "default" }
        return sound.displayName.lowercased()
    }
```

- [ ] **Step 4: 写 AlertSoundPickerView**

Create `BarkMate/App/Sources/Views/AlertSoundPickerView.swift`:
```swift
//
//  AlertSoundPickerView.swift
//  BarkAgent
//
//  声音选择屏。全局默认 + 三个可覆盖 status。点击 = 选中 + 试听。
//

import SwiftUI
import Factory
import Models
import Store
import DesignSystem

struct AlertSoundPickerView: View {

    @Injected(\.alertSoundStore) private var store: AlertSoundStore

    // 触发重绘:选中态存在 store(UserDefaults),用本地镜像驱动 UI。
    @State private var globalID: String = SoundCatalog.systemDefaultID
    @State private var overrides: [AgentStatus: String] = [:]
    // 当前正在为哪个 status 选择;nil = 选择全局默认。
    @State private var editingStatus: AgentStatus? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MCConsoleHeader(
                    crumbs: ["SYS", "SETTINGS", "SOUND"],
                    title: "Alert sound"
                )
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 0) {
                    MCSectionHeader("Default", trailing: "global")
                    ForEach(SoundCatalog.all) { sound in
                        soundRow(sound, selectedID: globalID, status: nil)
                    }

                    MCSectionHeader("Per-status", trailing: "override")
                    ForEach(AlertSoundStore.overridableStatuses, id: \.self) { status in
                        statusRow(status)
                    }

                    if let editingStatus {
                        MCSectionHeader(
                            statusLabel(editingStatus),
                            trailing: "pick"
                        )
                        useDefaultRow(for: editingStatus)
                        ForEach(SoundCatalog.barkSounds) { sound in
                            soundRow(
                                sound,
                                selectedID: overrides[editingStatus],
                                status: editingStatus
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .mcScreenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("alert-sound-picker")
        .onAppear(perform: loadState)
    }

    // MARK: - Rows

    private func soundRow(_ sound: AlertSound, selectedID: String?, status: AgentStatus?) -> some View {
        Button {
            select(sound: sound, for: status)
        } label: {
            MCSettingRow(title: sound.displayName) {
                MCSettingValue(
                    selectedID == sound.id ? "✓" : "",
                    tone: .accent
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(status == nil ? "sound-row-\(sound.id)" : "sound-row-\(status!.rawValue)-\(sound.id)")
        .accessibilityAddTraits(selectedID == sound.id ? [.isSelected] : [])
    }

    private func statusRow(_ status: AgentStatus) -> some View {
        Button {
            editingStatus = (editingStatus == status) ? nil : status
        } label: {
            MCSettingRow(
                title: statusLabel(status),
                detail: nil
            ) { MCSettingValue(overrideLabel(status)) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("status-row-\(status.rawValue)")
    }

    private func useDefaultRow(for status: AgentStatus) -> some View {
        Button {
            store.setOverride(id: nil, for: status)
            overrides[status] = nil
        } label: {
            MCSettingRow(title: "Use default") {
                MCSettingValue(overrides[status] == nil ? "✓" : "", tone: .accent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sound-row-\(status.rawValue)-default")
    }

    // MARK: - Actions

    private func select(sound: AlertSound, for status: AgentStatus?) {
        if let status {
            store.setOverride(id: sound.id, for: status)
            overrides[status] = sound.id
        } else {
            store.setGlobalDefault(id: sound.id)
            globalID = sound.id
        }
        SoundPreviewPlayer.shared.play(fileName: sound.fileName)
    }

    private func loadState() {
        globalID = store.globalDefaultID() ?? SoundCatalog.systemDefaultID
        var map: [AgentStatus: String] = [:]
        for status in AlertSoundStore.overridableStatuses {
            if let id = store.overrideID(for: status) { map[status] = id }
        }
        overrides = map
    }

    // MARK: - Labels

    private func statusLabel(_ status: AgentStatus) -> String {
        switch status {
        case .waitingInput: return "Waiting input"
        case .blocked: return "Blocked"
        case .failed: return "Failed"
        default: return status.rawValue
        }
    }

    private func overrideLabel(_ status: AgentStatus) -> String {
        guard
            let id = overrides[status],
            let sound = SoundCatalog.sound(for: id)
        else { return "default" }
        return sound.displayName.lowercased()
    }
}
```

- [ ] **Step 5: 生成工程 + 编译**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodegen generate
xcodebuild -project BarkMate.xcodeproj -scheme BarkMate -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 6: Run UI test to verify it passes**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodebuild test -project BarkMate.xcodeproj -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:BarkMateUITests/BarkMateFunctionalSmokeTests/testAlertSoundPickerOpensAndSelects 2>&1 | tail -15
```
Expected: `** TEST SUCCEEDED **`。(若模拟器 iPhone 16 不存在,用 `xcrun simctl list devices available` 选一个替换。)

- [ ] **Step 7: Commit**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add BarkMate/App/Sources/Views/SettingsView.swift BarkMate/App/Sources/Views/AlertSoundPickerView.swift BarkMate/App/UITests/BarkMateUITests/BarkMateFunctionalSmokeTests.swift BarkMate/BarkMate.xcodeproj
git commit -m "feat: alert sound picker with per-status selection + preview"
```

---

### Task 8: 全量回归 + 真机验证

**Files:** 无(验证任务)

**Interfaces:**
- Consumes: Task 1–7 全部产物。
- Produces: 通过标准的可发布功能。

- [ ] **Step 1: 全包单测**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate/Packages/Store && swift test 2>&1 | tail -5
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate/Packages/BarkService && swift test 2>&1 | tail -5
```
Expected: 两个包全绿,无既有测试回归。

- [ ] **Step 2: App 单测 + UI 测试全量**

Run:
```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent/BarkMate
xcodebuild test -project BarkMate.xcodeproj -scheme BarkMate \
  -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`。

- [ ] **Step 3: 真机验证清单(手动,对照 spec 验收标准)**

在真机执行并逐项确认:
1. Settings → 点 "Alert sound" → 进入选择屏。
2. 点任一声音 → 立即听到试听(**打开手机静音开关再点,仍应出声**)。
3. 选中项显示 ✓;杀进程重开 app → 选择保留。
4. 为 waiting_input / blocked / failed 各选不同声音;未设置的回落全局默认。
5. 用 curl 向自己的 bark server 发带 `agent_status=failed` 的推送 → 通知按所选声音播报;
   设为 silence 的 status → 到达但不响;未配置 → 保持发送方原声。

- [ ] **Step 4: 收尾提交(若真机验证产生微调)**

```bash
cd /Users/mac/Zero/Proj/Coding/rtxiii/BarkAgent
git add -A && git commit -m "test: verify alert sound end-to-end on device"
```

---

## Self-Review

**1. Spec coverage:**
- 数据模型/SoundCatalog → Task 2 ✓
- AlertSoundStore + 回落链 → Task 3 ✓
- SettingsView 可点击行 → Task 7 ✓
- AlertSoundPickerView 两级结构 → Task 7 ✓
- SoundPreviewPlayer 无视静音键 → Task 4 ✓
- NSE applyAlertSound + 仅配置过才覆盖 → Task 5 ✓
- 资源集成 XcodeGen + MIT 归属 → Task 1 ✓
- 四类测试(SoundCatalog/AlertSoundStore/AlertSoundResolution/UI smoke)→ Task 2/3/5/7 ✓
- DI 注册 → Task 6 ✓

**2. Placeholder scan:** 无 TBD/TODO;所有代码步骤含完整代码。Task 7 Step 1 明确要求实现前核对既有 UI helper 名称(非占位,是必要的现场校验)。

**3. Type consistency:**
- `AlertSound(id/displayName/fileName)` 全任务一致。
- `SoundCatalog.systemDefaultID / silenceID / sound(for:) / all / barkSounds` 一致。
- `AlertSoundStore.setGlobalDefault/globalDefaultID/setOverride/overrideID/resolvedSoundID/overridableStatuses` 在 Task 3 定义,Task 5/6/7 调用签名一致。
- `SoundDecision.keep/.silence/.named` 与 `AlertSoundResolver.decide` 在 Task 5 定义并被 NSE 消费,一致。
- `SoundPreviewPlayer.shared.play(fileName:)` 在 Task 4 定义,Task 7 调用一致。
