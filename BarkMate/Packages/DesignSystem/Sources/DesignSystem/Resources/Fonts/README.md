# Mission Control Font Assets

把以下字体的 OTF/TTF 文件放在这个目录，文件名要与 `MissionControl.Font.Family` 的 PostScript 名一致：

## JetBrains Mono（等宽，主导）
- `JetBrainsMono-Regular.ttf` — 400
- `JetBrainsMono-Medium.ttf` — 500
- `JetBrainsMono-Bold.ttf` — 700
- `JetBrainsMono-ExtraBold.ttf` — 800

下载：https://github.com/JetBrains/JetBrainsMono/releases

## Inter Tight（显示字体，大标题）
- `InterTight-Bold.ttf` — 700
- `InterTight-ExtraBold.ttf` — 800
- `InterTight-Black.ttf` — 900

下载：https://fonts.google.com/specimen/Inter+Tight

## Instrument Serif（斜体强调）
- `InstrumentSerif-Regular.ttf` — 400
- `InstrumentSerif-Italic.ttf` — 400 italic

下载：https://fonts.google.com/specimen/Instrument+Serif

---

字体放好后，在 App 启动入口调用一次：

```swift
import DesignSystem

@main
struct BarkMateApp: App {
    init() {
        MissionControl.Font.register()
    }
    // ...
}
```

未放置字体时，所有 `MissionControl.Font.*` getter 会自动 fallback 到 system mono / system + design serif，不会崩。
