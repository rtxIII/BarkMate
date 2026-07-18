# BarkAgent

> 隐私优先的 iOS 个人信息收件箱。
> 统一归档 Bark 推送通知和本地 Markdown 备忘录。

## 要求

- Xcode 26+
- macOS 14+
- iOS 18.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## 首次使用

```bash
# 安装 XcodeGen（若未安装）
brew install xcodegen

# 生成 Xcode 工程
cd BarkMate
xcodegen generate

# 打开工程
open BarkMate.xcodeproj
```

## 项目结构

```
BarkMate/
├── project.yml                          # XcodeGen 配置
├── App/                                 # 主应用
├── NotificationServiceExtension/        # 推送服务 Extension
├── ShareExtension/                      # Share Sheet Extension
├── Widgets/                             # Widget Extension
├── Packages/                            # 本地 SPM 模块
│   ├── Models/                          # SwiftData 数据模型
│   ├── BarkService/                     # Bark 协议实现
│   ├── Store/                           # 数据访问层
│   ├── MemoKit/                         # 备忘录编辑器
│   └── DesignSystem/                    # 共享 UI 组件
└── Tests/                               # 集成测试
```

## 共享配置

- **App Group**: `group.com.barkagent.shared`
- **Keychain Group**: `$(AppIdentifierPrefix)com.barkagent.shared`
- **Bundle ID**: `com.barkagent.ios`

## TestFlight 提交清单

### 提交前自检

- [ ] `xcodegen generate` 已重新生成最新工程
- [ ] Release 构建通过:`xcodebuild -scheme BarkMate -configuration Release -sdk iphoneos build`
- [ ] `App/Resources/PrivacyInfo.xcprivacy` 已随 BarkAgent.app 内置（构建产物里能搜到）
- [ ] `barkagent.we2.xyz/ping` 返回 200(默认推送服务器在线)
- [ ] `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` 已根据本轮提交更新

### App Store Connect 表单填写

| 字段 | 取值 |
|---|---|
| App Privacy → Data Collection | **Data Not Collected** (无任何数据收集) |
| Export Compliance | `ITSAppUsesNonExemptEncryption = false`(已在 Info.plist 设好,无需重复申报) |
| App Review → Notes | 粘贴 [REVIEW_NOTES.md](./REVIEW_NOTES.md) 全文 |
| App Review → Demo Account | 留空(无登录) |
| App Review → Sign-In required | No |

### 提交命令

```bash
cd BarkMate
xcodegen generate

# Archive
xcodebuild -project BarkMate.xcodeproj \
  -scheme BarkMate \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath build/BarkMate.xcarchive \
  archive

# Export → ipa(需要 ExportOptions.plist)
xcodebuild -exportArchive \
  -archivePath build/BarkMate.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist

# 上传到 TestFlight
xcrun altool --upload-app \
  -f build/ipa/BarkAgent.ipa \
  -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
```

### 已知 TestFlight 限制(写进 What to Test)

- Widgets 仅为占位卡片
- Agent detail 的 AI 摘要为静态占位文案,等待 Apple Intelligence 上线后接入

## 故障排查

### Shared storage unavailable

App 启动时若 App Group 容器不可用(entitlement 异常 / Sandbox 同步延迟),
会自动降级到 in-memory 模式并在 Setup tab 顶部显示红色 banner。修复方法:
卸载并重新安装 App,让系统重新初始化 App Group 容器。

## 文档

- 产品规格:`../doc/product.md`
- 技术设计:`../doc/design.md`
- 实施计划:`../doc/plan.md`
- 审核说明(给 ASC):[REVIEW_NOTES.md](./REVIEW_NOTES.md)

## License

(待定)

