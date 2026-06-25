//
//  MissionControl+Font.swift
//  DesignSystem
//
//  Mission Control 字体系统。
//
//  字体家族:
//  - 等宽:JetBrains Mono (主导, body / mono / 数字)
//  - 显示:Inter Tight (大标题 / Black weight)
//  - 衬线:Instrument Serif (斜体强调, agent 名 / Italic 标点)
//
//  字体文件应放置在:
//    `Packages/DesignSystem/Sources/DesignSystem/Resources/Fonts/`
//  并通过 `MissionControl.Font.register()` 在 App 启动时注册。
//
//  字体未注册时自动 fallback 到 system mono / system + design serif。
//

import SwiftUI
import CoreText
#if canImport(UIKit)
import UIKit
#endif

extension MissionControl {

    public enum Font {

        // MARK: - Family Names (用于 Font.custom)

        public enum Family {
            public static let mono = "JetBrainsMono-Regular"
            public static let monoMedium = "JetBrainsMono-Medium"
            public static let monoBold = "JetBrainsMono-Bold"
            public static let monoExtraBold = "JetBrainsMono-ExtraBold"

            public static let display = "InterTight-Black"
            public static let displayHeavy = "InterTight-ExtraBold"
            public static let displayBold = "InterTight-Bold"

            public static let serif = "InstrumentSerif-Regular"
            public static let serifItalic = "InstrumentSerif-Italic"
        }

        // MARK: - Type Scale (语义 token,组件层只调用这些)

        /// 96pt — 锁屏巨型时钟。Inter Tight Light。
        public static var clockGiant: SwiftUI.Font {
            interTight(size: 96, weight: .ultraLight)
        }

        /// 30pt — App bar 标题、Heads-up 标题。Inter Tight Black + Instrument Italic 强调。
        public static var titleXL: SwiftUI.Font {
            interTight(size: 30, weight: .black)
        }

        /// 22pt — Lock card / Detail 页 hero 主标题。
        public static var titleL: SwiftUI.Font {
            interTight(size: 22, weight: .black)
        }

        /// 18pt — 紧凑标题、卡片内强调。
        public static var titleM: SwiftUI.Font {
            interTight(size: 18, weight: .heavy)
        }

        /// 15pt — 内联组件标题、列表项主文。
        public static var titleS: SwiftUI.Font {
            interTight(size: 15, weight: .bold)
        }

        /// 13pt — 卡片正文、卡片内问题(`ask`) 文本。
        public static var bodyM: SwiftUI.Font {
            jetBrainsMono(size: 13, weight: .regular)
        }

        /// 12pt — 紧凑正文、列表副文。
        public static var bodyS: SwiftUI.Font {
            jetBrainsMono(size: 12, weight: .regular)
        }

        /// 11pt — Status code `[ WAIT ]`、telemetry row。
        public static var bodyMono: SwiftUI.Font {
            jetBrainsMono(size: 11, weight: .medium)
        }

        /// 10pt — Crumbs、section header、`SYS / OPS / DOSSIER` 等导航前缀。
        public static var captionMono: SwiftUI.Font {
            jetBrainsMono(size: 10, weight: .bold)
        }

        /// 9pt — Badge 内文、chip label、time stamp。
        public static var microMono: SwiftUI.Font {
            jetBrainsMono(size: 9, weight: .bold)
        }

        /// 斜体强调,用于 agent 名后缀(如 `test-writer` 的 italic "writer" 部分)。
        public static func italicAccent(size: CGFloat) -> SwiftUI.Font {
            instrumentSerif(size: size, italic: true)
        }

        // MARK: - Custom Constructors (有 fallback)

        /// JetBrains Mono with system mono fallback.
        public static func jetBrainsMono(size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            let name: String
            switch weight {
            case .bold, .heavy, .black:
                name = Family.monoBold
            case .semibold, .medium:
                name = Family.monoMedium
            case .ultraLight, .thin, .light:
                name = Family.mono
            default:
                name = Family.mono
            }
            if isRegistered(name) {
                return SwiftUI.Font.custom(name, size: size)
            }
            return .system(size: size, weight: weight, design: .monospaced)
        }

        /// Inter Tight with system fallback (sans-serif rounded heavy weight).
        public static func interTight(size: CGFloat, weight: SwiftUI.Font.Weight = .black) -> SwiftUI.Font {
            let name: String
            switch weight {
            case .black, .heavy:
                name = Family.display
            case .bold:
                name = Family.displayBold
            case .semibold:
                name = Family.displayHeavy
            case .ultraLight, .thin, .light:
                name = Family.displayBold
            default:
                name = Family.displayBold
            }
            if isRegistered(name) {
                return SwiftUI.Font.custom(name, size: size)
                    .weight(weight)
            }
            return .system(size: size, weight: weight, design: .default)
        }

        /// Instrument Serif italic with system serif fallback.
        public static func instrumentSerif(size: CGFloat, italic: Bool = true) -> SwiftUI.Font {
            let name = italic ? Family.serifItalic : Family.serif
            if isRegistered(name) {
                return SwiftUI.Font.custom(name, size: size)
            }
            let base = SwiftUI.Font.system(size: size, weight: .regular, design: .serif)
            return italic ? base.italic() : base
        }

        // MARK: - Registration

        /// 已注册过的字体名集合(避免重复注册告警)。
        ///
        /// 字体注册只在 App 启动期一次性发生,读路径由 NSLock 串行化。
        nonisolated(unsafe) private static var registeredNames: Set<String> = []
        private static let registrationLock = NSLock()

        /// 在 App 启动时调用一次,将 DesignSystem bundle 内字体注册进 CoreText。
        ///
        /// 字体文件应放在 DesignSystem package 的 `Resources/Fonts/` 目录,
        /// 并在 `Package.swift` 的 target 中声明 `.process("Resources")`。
        ///
        /// 字体未就位时函数无副作用,所有 token getter 会 fallback 到 system 字体。
        public static func register() {
            register(bundle: .module)
        }

        /// 自定义 bundle 注册入口(测试或宿主 App 携带字体时使用)。
        public static func register(bundle: Bundle) {
            let fontFiles: [String] = [
                Family.mono,
                Family.monoMedium,
                Family.monoBold,
                Family.monoExtraBold,
                Family.display,
                Family.displayHeavy,
                Family.displayBold,
                Family.serif,
                Family.serifItalic
            ]
            for name in fontFiles {
                registerFont(named: name, bundle: bundle)
            }
        }

        private static func registerFont(named postScriptName: String, bundle: Bundle) {
            registrationLock.lock()
            let already = registeredNames.contains(postScriptName)
            registrationLock.unlock()
            guard !already else { return }

            // 同时尝试 .otf / .ttf 两种后缀。
            let extensions = ["otf", "ttf"]
            for ext in extensions {
                if let url = bundle.url(forResource: postScriptName, withExtension: ext) {
                    var error: Unmanaged<CFError>?
                    if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                        registrationLock.lock()
                        registeredNames.insert(postScriptName)
                        registrationLock.unlock()
                        return
                    }
                }
            }
        }

        /// 判断字体是否在系统或 bundle 中可用。
        private static func isRegistered(_ name: String) -> Bool {
            registrationLock.lock()
            let inSet = registeredNames.contains(name)
            registrationLock.unlock()
            if inSet { return true }
            #if canImport(UIKit)
            return UIFont(name: name, size: 12) != nil
            #else
            return false
            #endif
        }
    }
}
