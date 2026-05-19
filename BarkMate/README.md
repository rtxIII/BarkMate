# BarkMate

> 隐私优先的 iOS 个人信息收件箱。
> 统一归档 Bark 推送通知和本地 Markdown 备忘录。

## 要求

- Xcode 15.4+
- macOS 14+
- iOS 17.0+ deployment target
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

- **App Group**: `group.com.barkmate.shared`
- **Keychain Group**: `$(AppIdentifierPrefix)com.barkmate.shared`
- **Bundle ID**: `com.barkmate.ios`

## 文档

- 产品规格：`../doc/product.md`
- 技术设计：`../doc/design.md`
- 实施计划：`../doc/plan.md`

## License

（待定）
