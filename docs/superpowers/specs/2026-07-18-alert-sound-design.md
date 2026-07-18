# Alert Sound —— Per-status 可覆盖 + 试听 + 推送生效

- 日期: 2026-07-18
- 分支: fix/progress-rendering-gap
- 状态: 已批准设计,待实现

## 背景与问题

Settings 屏的 "Alert sound" 行(`BarkMate/App/Sources/Views/SettingsView.swift:78-81`)
真机点击无任何反应。

根因调查(systematic-debugging Phase 1)结论:**这不是回归 bug,而是该功能从未实现**。

证据:

- 该行是裸 `MCSettingRow`,没有包 `Button`、没有 action、没有 state
  (对比同屏可点击的 "Manage servers" `SettingsView.swift:56`、
  "Re-run installer" `SettingsView.swift:90`,二者都显式包了 `Button`)。
- `MCSettingRow` 组件本身是纯展示,无任何手势(`MCSettingRow.swift:33-58`)。
- 全代码库零音频播放 API(无 `AVAudioPlayer` / `AudioServicesPlay` / `SystemSoundID`)。
- 该行文案 "Per-status override · default = system." 描述了一个尚不存在的能力。

范围决策(已与用户确认):做**完整功能** —— 点击进入声音选择、可试听、可保存、
且 APNs 推送到达时按所选声音播报。

## 关键约束(已验证)

1. **iOS 通知声音只能用 bundle 内的 `.caf` 文件或 `.default`**。无法把任意
   `AudioServicesPlaySystemSound` 系统音效用作推送声音。→ 必须往 bundle 引入真实音频文件。
2. `UNNotificationSound(named:)` 只识别 **main bundle 根目录**的 `.caf`。
   → 文件必须打进 App 与 NSE 两个 target 的资源,不能只放 SPM resource bundle(嵌套子目录系统识别不到)。
3. 试听只能在 App 进程内做(`AVAudioPlayer`);NSE 无法播放声音,只能设置 `content.sound`。
4. App 与 NSE 已共享 App Group `group.com.barkagent.shared`
   (双方 entitlement 均已配置,见 `project.yml:85-88` 与 `:127-130`),
   天然作为 App→NSE 的偏好共享通道。

## 声音资源来源(已确认)

采用 **Bark 官方声音集**(github.com/Finb/Bark,MIT 许可)。
`Sounds/` 目录共 33 个 `.caf` 文件,已探测确认包含:

```
alarm anticipate bell birdsong bloom calypso chime choo descent electronic
fanfare glass gotosleep healthnotification horn ladder mailsent minuet
multiwayinvitation newmail newsflash noir paymentsuccess shake sherwoodforest
silence spell suspense telegraph tiptoes typewriters update
```

其中 `silence.caf` 天然对应"静音"档(到达但不响)。

## 架构总览

三层,复用现有 App Group 通道:

```
┌─ App (SettingsView → AlertSoundPickerView) ──────────┐
│  用户为每个 status 选声音 → AVAudioPlayer 即时试听    │
│  写入 App Group UserDefaults                          │
└──────────────────────┬────────────────────────────────┘
                       │ group.com.barkagent.shared (已配好)
┌──────────────────────▼────────────────────────────────┐
│  NSE (NotificationService.processPipeline)             │
│  读该推送的 agent_status → 查偏好 →                     │
│  content.sound = UNNotificationSound(named: X.caf)     │
└────────────────────────────────────────────────────────┘
      .caf 文件同时打进 App bundle + NSE bundle 根目录
```

## 一、数据模型与持久化(放 `Store` 包,App 与 NSE 共享)

App 与 NSE 都已依赖 `Store`(`project.yml:99-139`),因此新类型放此包两端天然可用,不新增依赖。

### SoundCatalog

```swift
public struct AlertSound: Identifiable, Hashable {
    public let id: String           // 文件名去扩展名, e.g. "bell"
    public let displayName: String  // "Bell"
    public let fileName: String     // "bell.caf"
}
```

- `SoundCatalog.all`:33 个 Bark 声音的静态清单 + 两个特殊档:
  - `.systemDefault`:不写文件,推送时保持发送方原声/回落 `.default`。
  - `.silence`:用 `silence.caf`,即"到达但不响"。
- 清单**静态硬编码**,不做运行时目录扫描 —— 可测、无 I/O、启动零开销。

### AlertSoundStore

- 存储:`UserDefaults(suiteName: "group.com.barkagent.shared")`,与现有 App Group 一致。
  测试时可注入自定义 suite(项目已有 `BARKAGENT_TEST_DEFAULTS_SUITE` 模式,见 `Container+App.swift:150`)。
- key 前缀 `alertSound.`:
  - `alertSound.default` —— 全局默认(所有未单独配置的 status 用它)。
  - `alertSound.<status>` —— 各 status 的可选 override(如 `alertSound.waiting_input`)。
- 存**声音 id 字符串**(如 `"bell"`),经 `SoundCatalog` 映射到 `.caf`,
  避免文件扩展名散落各处。
- **Per-status 回落语义**:查某 status 声音时
  `alertSound.<status>` → 无则 `alertSound.default` → 无则系统默认(`UNNotificationSound.default`)。

对应的 `AgentStatus`(`Models/Enums.swift:8-16`):
`running / waiting_input / blocked / done / failed / stale`。

## 二、UI 与试听

### 改动 1:SettingsView 的 Alert sound 行

`SettingsView.swift:78-81` 由裸行改为可点击行,写法对齐同屏 "Manage servers":

```swift
Button { showSoundPicker = true } label: {
    MCSettingRow(
        title: "Alert sound",
        detail: "Per-status override · default = system."
    ) { MCSettingValue(globalSoundLabel) }   // 显示当前全局默认声音名, e.g. "BELL"
}
.buttonStyle(.plain)
.accessibilityIdentifier("settings-alert-sound")
```

配 `navigationDestination(isPresented: $showSoundPicker) { AlertSoundPickerView() }`。

### 改动 2:新建 AlertSoundPickerView(`App/Sources/Views/`,Mission Control 风格)

单屏两级结构:

```
┌ MCConsoleHeader  crumbs:[SYS · SETTINGS · SOUND] ─────┐
│ MCSectionHeader "Default"        ← 全局默认            │
│   [✓] Bell            ▸ tap = 选中+试听               │
│   [ ] Electronic                                       │
│   ...(33 项 + System default + Silence)               │
│                                                        │
│ MCSectionHeader "Per-status"     ← 可选覆盖            │
│   Waiting input   → BELL      ▸ tap 进子选择           │
│   Blocked         → default                            │
│   Failed          → default                            │
└────────────────────────────────────────────────────────┘
```

- **点击行为**:点任意声音行 = ① 写入 `AlertSoundStore` ② `AVAudioPlayer` 立即试听该 `.caf`
  ③ 打勾。这直接修复"点击没反应"。
- **可单独覆盖的 status**:`waiting_input / blocked / failed`(需用户即时介入的),
  与文案 "wait_input · blocked · failed break quiet mode."(`SettingsView.swift:74`)一致;
  `running / done / stale` 用全局默认,避免 UI 过载。
- **Per-status 子选择**:复用同一声音列表组件,顶部多一个 "Use default" 项(清除该 status override)。
- 复用现有 `MCSettingRow` + 勾选态徽章,不新建视觉组件。

### 改动 3:SoundPreviewPlayer(App 内轻量试听器)

- `AVAudioPlayer` 封装,单例。
- 播放前 `try AVAudioSession.setCategory(.playback)`,保证真机静音开关下试听仍出声
  (试听场景应无视静音键)。
- 切换声音时停掉上一条。
- NSE 侧不涉及(NSE 只设 `content.sound`,不播放)。

## 三、NSE 推送生效

改动 `NotificationService.processPipeline`(`NotificationService.swift:48-73`),
在 `applyDecrypted` 之后、`ImageEnricher` 之前插入:

```swift
applyDecrypted(content: content, from: outcome.decryptResult)
applyAlertSound(content: content, from: outcome.decryptResult)   // ← 新增
await ImageEnricher()...
```

`applyAlertSound` 逻辑:

1. 从 `result.userInfo` 解析 `agent_status`(复用 `PushParser` 既有的 `agent_status`
   提取逻辑,`PushParser.swift:112`,不重复解析)。
2. `AlertSoundStore.resolvedSound(for: status)` → 按回落链得到 `AlertSound?`。
3. 设置 `content.sound`:
   - `.systemDefault` 或解析不到 status → **不改**,保留发送方 payload 原声(尊重 Bark 协议既有行为)。
   - 具体声音 → `content.sound = UNNotificationSound(named: UNNotificationSoundName(fileName))`。
   - `.silence` → `content.sound = nil`(到达但不响)。

**关键决策**:仅当用户**主动配置过**才覆盖发送方声音。未配置时完全不动 `content.sound`,
保持现有行为 —— 对老用户零副作用(Surgical Changes)。

## 四、资源集成(XcodeGen,已确认可脚本化)

- `.caf` 放新目录 `BarkMate/Shared/Sounds/`。
- `project.yml`:
  - App target(`BarkMate`)`sources` 增加 `- path: Shared/Sounds`。
  - NSE target(`NotificationServiceExtension`)`sources` 增加 `- path: Shared/Sounds`。
- `xcodegen generate` 后,两个 target 各自的 Copy Bundle Resources 自动含全部 `.caf`。
- 许可:Bark 为 MIT,在 `Shared/Sounds/` 放 `LICENSE-sounds.md` 注明来源与许可。

## 五、测试策略(TDD,与项目现有测试同构)

| 测试 | 位置 | 验证 |
|---|---|---|
| `SoundCatalogTests` | StoreTests | 清单含 33+2 项、id↔fileName 映射、无重复 |
| `AlertSoundStoreTests` | StoreTests | 注入 suite;per-status 写读;回落链(status→default→nil);清除 override |
| `AlertSoundResolutionTests` | BarkServiceTests 或 App Tests | 给定 userInfo+偏好 → 期望的 `UNNotificationSound`/nil/不覆盖 |
| UI smoke | BarkMateUITests | 点 `settings-alert-sound` → picker 出现 → 点一项 → 勾选态变化 |

试听的 `AVAudioPlayer` 真机行为不做单测(依赖音频硬件),靠手动真机验证。

## 验收标准

1. 真机点击 Settings → Alert sound 行,进入声音选择屏。
2. 点击任一声音,立即听到该声音试听(真机静音开关下仍出声)。
3. 选择被持久化;重进 app 后选择保留。
4. 可为 waiting_input / blocked / failed 分别设置不同声音,未设置的回落全局默认。
5. 收到对应 status 的 APNs 推送时,通知按所选声音播报;`.silence` 到达不响;
   未配置则保持发送方原声。
6. 全部新增单测通过;既有测试不回归。

## 超出本次范围(YAGNI)

- 不做"发送端"声音配置(本 app 是接收端)。
- running / done / stale 不提供 per-status 覆盖(用全局默认)。
- 不做自定义音频导入。
