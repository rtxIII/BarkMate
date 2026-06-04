---
title: BarkAgent iOS Permission Strings (i18n)
version: 1.0
updated: 2026-05-27
---

# 权限描述本地化 / Permission Strings i18n

App Store Connect 在审核与提交时会检查 `Info.plist` 中所有 `NS*UsageDescription`
键的内容。本文档给出 BarkAgent **当前 V1.0 实际需要**的权限文案,中英双语对照,
并标注未来 Phase 引入相机/照片库等权限时的占位文案。

## 1. 当前需要的权限 (V1.0)

V1.0 使用推送通知 (UNUserNotifications) 和 SwiftUI `PhotosPicker`。
推送通知**不需要** `NS*UsageDescription` 键,系统会用自带文案弹窗。
`PhotosPicker` 由系统选择器授权单次选中的图片,也**不需要**
`NSPhotoLibraryUsageDescription`。其他系统弹窗文案在 App Store Connect 的
App Privacy 与 Data Linked to User 里声明。

### 1.1 当前 `BarkMate/App/Info.plist` 状态 (供清理参考)

| 现存 key | 是否有效 | 建议 |
|---|---|---|
| `NSUserNotificationsUsageDescription` | ❌ 非 Apple 标准 key | 删除。`UNUserNotificationCenter.requestAuthorization` 自带系统文案 |
| `NSPhotoLibraryUsageDescription` | ✅ 但 `PhotosPicker` 不需要 | 删除。当前只读取用户在系统 picker 中主动选择的图片,不请求完整相册权限 |

> 检查命令:
> ```sh
> /usr/libexec/PlistBuddy -c "Print" BarkMate/App/Info.plist
> ```

## 2. App Store Connect → App Privacy 声明

V1.0 在 App Privacy 表里勾选:

| 类别 | 是否收集 | 说明 |
|---|:---:|---|
| Contact Info | ❌ | 不申请 |
| Health & Fitness | ❌ | 不申请 |
| Financial Info | ❌ | 不申请 |
| Location | ❌ | 不申请 |
| Sensitive Info | ❌ | 不申请 |
| Contacts | ❌ | 不申请 |
| User Content | ⚠️ Stored on Device | 推送记录、Memo、用户选择的图片附件仅留本机 |
| Browsing History | ❌ | 不申请 |
| Search History | ❌ | 不申请 |
| Identifiers | ⚠️ Device ID (APNs token) | 用于推送投递,**不**用于跟踪 |
| Purchases | ❌ | 不申请 |
| Usage Data | ❌ | 不申请 |
| Diagnostics | ❌ | 无 crash / analytics |
| Other Data | ❌ | 不申请 |

Data Use 选项: **App Functionality only**(APNs token 用于推送投递)。
"Used for tracking?" → **No**。

## 3. Phase 4.3 (V1.1) — QR 相机扫码

未来引入 `AVCaptureSession` 扫码服务器后,需要在 Info.plist 加:

### NSCameraUsageDescription

```xml
<key>NSCameraUsageDescription</key>
<string>BarkAgent uses the camera only to scan QR codes that contain server
addresses, so you can add a Bark server without typing the URL.</string>
```

### zh-Hans 本地化 (`zh-Hans.lproj/InfoPlist.strings`)

```
"NSCameraUsageDescription" = "BarkAgent 仅在您扫描包含服务器地址的二维码时使用相机,以便免去手动输入服务器 URL。";
```

### en 本地化 (`en.lproj/InfoPlist.strings`)

```
"NSCameraUsageDescription" = "BarkAgent uses the camera only to scan QR codes containing server addresses, so you can add a Bark server without typing the URL.";
```

## 4. 未来直接访问照片库时的文案

当前 `PhotosPicker` 不需要照片库权限。未来如果改为直接使用 PhotoKit 访问
照片库,才需要:

### NSPhotoLibraryUsageDescription

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>BarkAgent needs photo library access only when you attach an image
to a memo. Attachments stay on your device.</string>
```

### NSPhotoLibraryAddUsageDescription (可选,仅当 App 写回照片库时需要)

当前计划只**读**用户选择的附件,不写回相册,故此键**不**需要。

### zh-Hans

```
"NSPhotoLibraryUsageDescription" = "BarkAgent 仅在您为备忘录附加图片时访问相册,附件保留在本机。";
```

### en

```
"NSPhotoLibraryUsageDescription" = "BarkAgent needs photo library access only when you attach an image to a memo. Attachments stay on your device.";
```

## 5. 不会请求的权限

以下权限 BarkAgent 任何 Phase 都**不**会请求,故 Info.plist 内**不应**出现
对应的 UsageDescription 键。审核员会因"声明但未使用"的权限拒审。

- NSLocationWhenInUseUsageDescription / NSLocationAlwaysUsageDescription
- NSMicrophoneUsageDescription
- NSContactsUsageDescription
- NSCalendarsUsageDescription
- NSRemindersUsageDescription
- NSHealthShareUsageDescription / NSHealthUpdateUsageDescription
- NSMotionUsageDescription
- NSSpeechRecognitionUsageDescription
- NSAppleMusicUsageDescription
- NSBluetoothAlwaysUsageDescription
- NSFaceIDUsageDescription
- NSUserTrackingUsageDescription (无 IDFA)

## 6. CFBundleLocalizations / 本地化语言

V1.0 计划同时提交简体中文 + 英文,建议 plist 加:

```xml
<key>CFBundleLocalizations</key>
<array>
    <string>en</string>
    <string>zh-Hans</string>
</array>
<key>CFBundleDevelopmentRegion</key>
<string>en</string>
```

`$(DEVELOPMENT_LANGUAGE)` 当前由 xcconfig 注入,确认其值为 `en`。

## 7. 出口管制 (ITSAppUsesNonExemptEncryption)

BarkAgent 在 NSE 使用 CryptoSwift 做 AES 端到端解密,属于"使用加密但仅
用于身份验证/数据保护/HTTPS"的场景,**符合 Apple 出口管制豁免**(EAR
§740.17(b)(1))。

在 Info.plist 中明确声明:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

可避免每次 TestFlight 提交时被问加密合规问卷。

## 8. 检查清单

- [x] 删除 Info.plist 里的无效 `NSUserNotificationsUsageDescription`
- [x] 删除 Info.plist 里当前不需要的 `NSPhotoLibraryUsageDescription`
- [x] Info.plist 加 `ITSAppUsesNonExemptEncryption = false`
- [x] Info.plist 加 `CFBundleLocalizations = [en, zh-Hans]`
- [x] 当前无需要本地化的 usage string;`InfoPlist.strings` 等 V1.1 加 Camera key 时再创建
- [ ] App Store Connect → App Privacy 按本节 §2 勾选
- [ ] 提交时声明出口管制 = 豁免
