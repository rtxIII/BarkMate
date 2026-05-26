//
//  Theme.swift
//  DesignSystem
//
//  BarkMate 的设计语言。所有视觉令牌的单一来源,Phase 3 mock 基线见
//  `App/Sources/Views/AgentMock/AgentMockPrototypeView.swift`。
//

import SwiftUI
import Models
#if canImport(UIKit)
import UIKit
#endif

public enum BarkTheme {

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
    }

    public enum Corner {
        public static let chip: CGFloat = 6
        public static let card: CGFloat = 12
        public static let mockCard: CGFloat = 22
        public static let largeCard: CGFloat = 24
        public static let hero: CGFloat = 30
    }

    public enum Palette {
        public static let ink = Color(hex: 0x121A20)
        public static let inkDeep = Color(hex: 0x273843)
        public static let paperHot = Color(hex: 0xFFF8EC)
        public static let paperWarm = Color(hex: 0xF1E7D6)
        public static let paperCool = Color(hex: 0xE7DAC8)
        public static let paperDeep = Color(hex: 0xE2D4BF)
        public static let accentBlue = Color(hex: 0x246BFE)
        public static let warningYellow = Color(hex: 0xEAB33D)
        public static let alertOrange = Color(hex: 0xEE6F2F)
        public static let successGreen = Color(hex: 0x2CA462)
        public static let errorRed = Color(hex: 0xD94735)
        public static let mutedGray = Color(hex: 0x737B71)
        public static let infoCyan = Color(hex: 0x1EA5B5)

        public static let cardBackground: Color = {
            #if canImport(UIKit)
            return Color(uiColor: .secondarySystemGroupedBackground)
            #else
            return Color.gray.opacity(0.1)
            #endif
        }()

        public static let chipBackground: Color = {
            #if canImport(UIKit)
            return Color(uiColor: .tertiarySystemFill)
            #else
            return Color.gray.opacity(0.15)
            #endif
        }()

        public static let groupPill = accentBlue.opacity(0.15)
    }

    public enum Typography {
        public static func heroSerif(size: CGFloat, weight: Font.Weight = .bold) -> Font {
            #if canImport(UIKit)
            if UIFont(name: "Iowan Old Style", size: size) != nil {
                return Font.custom("Iowan Old Style", size: size).weight(weight)
            }
            #endif
            return .system(size: size, weight: weight, design: .serif)
        }
    }
}

extension AgentStatus {
    /// Mock 视觉契约的标签文案(uppercase 由调用方决定)。
    public var label: String {
        switch self {
        case .running: return "running"
        case .waitingInput: return "waiting"
        case .blocked: return "blocked"
        case .done: return "done"
        case .failed: return "failed"
        case .stale: return "stale"
        }
    }

    public var color: Color {
        switch self {
        case .running: return BarkTheme.Palette.accentBlue
        case .waitingInput: return BarkTheme.Palette.warningYellow
        case .blocked: return BarkTheme.Palette.alertOrange
        case .done: return BarkTheme.Palette.successGreen
        case .failed: return BarkTheme.Palette.errorRed
        case .stale: return BarkTheme.Palette.mutedGray
        }
    }

    /// 优先级排序:waitingInput / blocked / failed 顶到最前,done 沉底。
    public var sortPriority: Int {
        switch self {
        case .waitingInput: return 1
        case .blocked: return 2
        case .failed: return 3
        case .running: return 4
        case .stale: return 5
        case .done: return 6
        }
    }

    public var isTerminal: Bool {
        switch self {
        case .done, .failed: return true
        case .running, .waitingInput, .blocked, .stale: return false
        }
    }
}

extension Color {
    /// 0xRRGGBB hex 构造。
    public init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0,
            opacity: alpha
        )
    }
}
