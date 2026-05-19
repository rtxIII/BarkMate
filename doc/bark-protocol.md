# Bark 协议摘要

> 基于 huangfeng/Bark 项目源码（`Bark/`）。供 BarkMate Phase 2 推送管线参考。
> 日期：2026-04-20 ｜ 来源文件：`Bark/Common/Moya/BarkApi.swift`、`Bark/Model/Algorithm.swift`、
> `Bark/NotificationServiceExtension/`、`Bark/Common/Client.swift`、`Bark/Controller/ServerListViewModel.swift`

---

## 1. HTTP 接口

### `POST /register`
注册或更新设备 token。

**请求体**（`application/x-www-form-urlencoded`）：
```
devicetoken=<APNs hex token>
key=<existing server-assigned key, optional>
```

**响应**：
```json
{ "code": 200, "data": { "key": "<server-assigned key>", ... } }
```

**特殊用法**：
- 删除服务器时调用 `register(key=oldKey, devicetoken="deleted")` 让服务器侧失效推送链接
- 若不传 `key` 或传空，服务器分配新 key

### `GET /ping`
健康检查。

**响应**：`{ "code": 200, ... }`

### 通用响应约定
- HTTP 200 + JSON 顶层 `code == 200` 才算成功
- 错误时 `message` 字段提供可读描述
- 默认服务器：`https://api.day.app`

---

## 2. 推送 Payload（明文）

APNs payload `userInfo` 字典字段（**全部顶层**，非 `aps` 子结构）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | string | 可选 UUID；未传则 Extension 生成 |
| `aps.alert.title` | string | 标题 |
| `aps.alert.subtitle` | string | 副标题 |
| `aps.alert.body` | string | 正文 |
| `aps.sound` | string | 提示音文件名（自动 .caf 后缀）|
| `aps.badge` | number | App badge |
| `url` | string | 点击通知打开的 URL |
| `image` | string | 图片 URL（Extension 下载并附加）|
| `group` | string | 通知分组（threadIdentifier）|
| `markdown` | string | 替代 body，渲染 markdown |
| `isarchive` | string | "0"/"1" 覆盖默认归档设置 |
| `icon` | string | 自定义通知图标 URL（iOS 15+）|
| `level` | string | active / timeSensitive / passive / critical |
| `call` | string | "1" 时循环播放 30 秒铃声 |
| `autoCopy` + `copy` | string | "1" + 待复制文本 |
| `ciphertext` | string | 加密 payload（见下）|
| `iv` | string | 覆盖服务器配置的 iv |

> 推送字段名 **大小写不敏感**——Extension 全部转 lowercase 处理（见 `CiphertextProcessor.decrypt`）。

---

## 3. 端到端加密

**算法矩阵**（见 `Algorithm.swift`）：
- AES-128 / AES-192 / AES-256 × CBC / ECB / GCM × PKCS7 / noPadding

**约束**：
| 算法 | Key 长度 | IV 长度 |
|---|---|---|
| AES-128 | 16 字节 | CBC=16, GCM=12, ECB 无 |
| AES-192 | 24 字节 | 同上 |
| AES-256 | 32 字节 | 同上 |

**GCM 模式**：使用 `mode: .combined`（auth tag 拼接在密文后）。

**密文 payload 结构**：
- `ciphertext`：Base64 编码的密文
- `iv`：可选，覆盖客户端配置的默认 IV
- 解密后是 JSON 字符串，dictionary 包含上表中除 `ciphertext`/`iv` 外的所有字段

**降级策略**：
- 解密失败 → `body = "Decryption Failed"`，正常下发通知（不写 Realm/SwiftData）
- BarkMate 计划 V1 升级：解密失败时**保留原始密文**入库（Phase 2 task 2.12）

---

## 4. NotificationServiceExtension 处理顺序

`NotificationService.swift` 维护严格的 processor 流水线（按顺序）：

```
1. ciphertext   ← 必须最先；密文里可能装着所有字段
2. markdown
3. level        ← active/timeSensitive/passive/critical
4. badge
5. autoCopy
6. archive      ← 写入持久化（Bark：plist file drop；BarkMate：SwiftData 直写或 plist drop）
7. mute         ← 检查 group mute
8. call         ← 30s 循环铃声
9. setImage     ← 下载图片附件
10. setIcon     ← 必须最后（耗时易超时）
```

每个 processor `async throws`，抛 `NotificationContentProcessorError.error(content)` 表示提前下发并中止流水线（如解密失败）。

---

## 5. Extension ↔ App 通信

**Darwin Notification**：Extension 处理完后 post：
```swift
CFNotificationCenterPostNotification(
    CFNotificationCenterGetDarwinNotifyCenter(),
    CFNotificationName("com.bark.newmessage" as CFString),
    nil, nil, true
)
```

**BarkMate 命名建议**：`com.barkmate.newmessage`（避免与原 Bark 冲突）。

**主应用监听**：`CFNotificationCenterAddObserver` + `DispatchSourceProcessSignal` 触发 SwiftData `@Query` 刷新。

---

## 6. 持久化策略：Bark 的 plist 旁路

**为何不直接写 Realm/SwiftData**：Realm + Extension 内存压力 + 跨进程写冲突。

**Bark 做法**（`ArchiveProcessor.swift`）：
1. Extension 把消息序列化为 NSDictionary
2. 写入 App Group `pending_messages/<sha256(messageId)>.plist`
3. 主 App 启动 / 收到 Darwin notification 时扫描目录、入库、删 plist

**BarkMate 决策点**：
- Phase 1 已验证 SwiftData 跨 container 共享 → **可以直接写**
- 但 plist 旁路对 Extension 崩溃/超时更鲁棒
- **建议**：Phase 2 起始用直写（简单），Phase 2.4 加降级时引入 plist 旁路

---

## 7. 多服务器管理

每个 Server：`{ id, address, key, state, name? }`

**生命周期**：
- 添加：`POST /register` → 收到 key → 入库
- 删除：`POST /register?key=<oldKey>&devicetoken=deleted` → 服务器侧失效 → 本地删
- 重置 key：拿新 key、旧 key 走 deleted 流程
- 健康检查：定期 `GET /ping`

**默认服务器**：`https://api.day.app`（应用初始化时自动添加）

---

## 8. 关键依赖与替代

| Bark 用 | BarkMate 用 | 备注 |
|---|---|---|
| Realm | SwiftData | iOS 18+ |
| RxSwift / Moya | async/await + URLSession | 零依赖 |
| CryptoSwift | CryptoSwift | 同（暂无替代，Apple CryptoKit 不支持 ECB/可变 IV）|
| SwiftyJSON | Codable + JSONSerialization | 标准库 |
| DefaultsKit | UserDefaults + App Group suite | 标准库 |
| Kingfisher | URLSession 下载（Extension 内）| 减小 Extension 体积 |

---

## 9. BarkMate Phase 2 实现 checklist（按 plan.md 任务号）

- **2.1 / 2.2 BarkClient**：实现 `register` / `ping`，async/await，URLSession
- **2.3 Extension 入口**：仅透传现版本已就位，需补 processor 流水线
- **2.4 DecryptProcessor**：移植 `AESCryptoModel`，简化 `Algorithm`/`CryptoSettingFields` 数据模型
- **2.5 ParseProcessor**：从 userInfo 提取上表字段，构造 `Item` 对象
- **2.6 ArchiveProcessor**：先 SwiftData 直写；2.12 时再加 plist 旁路降级
- **2.7 Darwin Notification**：name = `com.barkmate.newmessage`
- **2.8 EnrichProcessor**：图片下载（直 URLSession，不引 Kingfisher）+ icon + sound
- **2.9 PresentProcessor**：返回 `UNMutableNotificationContent` 给系统
- **2.10 PendingQueue**：plist 旁路（参考 Bark `ArchiveProcessor` SHA256 文件名方案）
- **2.11 主 App 监听**：`CFNotificationCenter` + 触发 SwiftData 刷新
- **2.12 降级**：解密失败保留密文、图片失败保留 URL
