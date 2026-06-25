//
//  MissionControl+Color.swift
//  DesignSystem
//
//  Mission Control 色板。深底战术控制台调色板。
//  HUD 5 色:琥珀(wait) / 青(run) / 酸橙(done) / 橙(stuck) / 品红(fail)。
//

import SwiftUI

extension MissionControl {

    public enum Color {

        // MARK: - Surfaces (深底层级)

        /// `#0a0d0c` 最底层背景。Board / 锁屏 / Live Activity Island。
        public static let void = SwiftUI.Color(hex: 0x0A0D0C)

        /// `#131816` 一级容器。Heads-up 面板 / 大卡背景。
        public static let hull = SwiftUI.Color(hex: 0x131816)

        /// `#1A201D` 二级容器。tab hover / chip background。
        public static let hullUp = SwiftUI.Color(hex: 0x1A201D)

        /// `#050706` 最深极。Phone bezel / Dynamic Island。
        public static let abyss = SwiftUI.Color(hex: 0x050706)

        // MARK: - Lines & Rules

        /// `#2A302D` 主分隔线、卡片描边。
        public static let rule = SwiftUI.Color(hex: 0x2A302D)

        /// `#3A423E` 强调分隔线、悬停态描边。
        public static let ruleHot = SwiftUI.Color(hex: 0x3A423E)

        // MARK: - Ink (前景文字)

        /// `#E8EBD8` 主文字、标题。
        public static let ink = SwiftUI.Color(hex: 0xE8EBD8)

        /// `#98A092` 次级文字、metadata、时间戳。
        public static let inkSoft = SwiftUI.Color(hex: 0x98A092)

        /// `#717771` 弱化文字、stale 状态码。
        public static let inkMute = SwiftUI.Color(hex: 0x717771)

        // MARK: - HUD Status Palette (5 色)

        /// `#FFB000` 琥珀 — `waiting_input` / Live Activity 强调色 / "Needs you" 数字。
        public static let amber = SwiftUI.Color(hex: 0xFFB000)

        /// `#5CE1E6` 青 — `running` / 计数器活跃数 / 进度条主色。
        public static let cyan = SwiftUI.Color(hex: 0x5CE1E6)

        /// `#C4F154` 酸橙 — `done` / "OK" 状态码 / 在线指示。
        public static let lime = SwiftUI.Color(hex: 0xC4F154)

        /// `#FF6B35` 橙 — `blocked` / "STUCK" 状态码。
        public static let orange = SwiftUI.Color(hex: 0xFF6B35)

        /// `#FF4D8D` 品红 — `failed` / 异常告警 / 高对比强调。
        public static let magenta = SwiftUI.Color(hex: 0xFF4D8D)

        // MARK: - Glow (HUD 辉光,通常用在 shadow / box-shadow 处)

        public static let amberGlow = SwiftUI.Color(hex: 0xFFB000, alpha: 0.14)
        public static let cyanGlow = SwiftUI.Color(hex: 0x5CE1E6, alpha: 0.14)
        public static let limeGlow = SwiftUI.Color(hex: 0xC4F154, alpha: 0.14)
        public static let orangeGlow = SwiftUI.Color(hex: 0xFF6B35, alpha: 0.14)
        public static let magentaGlow = SwiftUI.Color(hex: 0xFF4D8D, alpha: 0.14)

        // MARK: - Semantic Aliases (供组件层使用,不要直接引用 amber/cyan)

        /// 主背景。
        public static let background = void

        /// 卡片背景。
        public static let surface = hull

        /// 卡片描边。
        public static let stroke = rule

        /// 强调描边(悬停 / focus)。
        public static let strokeHot = ruleHot

        /// 主品牌强调色(同 amber)。Mission Control 整体以琥珀为主调。
        public static let accent = amber

        /// 主前景文字。
        public static let foreground = ink

        /// 次级前景文字。
        public static let foregroundSoft = inkSoft
    }
}
