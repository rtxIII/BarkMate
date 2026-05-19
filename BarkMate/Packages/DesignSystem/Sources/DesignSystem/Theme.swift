//
//  Theme.swift
//  DesignSystem
//
//  BarkMate 的最小设计语言。iOS native 风格，统一间距/圆角/颜色引用。
//

import SwiftUI
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
    }

    public enum Palette {
        /// 卡片背景（深色模式自适应）。
        public static let cardBackground: Color = {
            #if canImport(UIKit)
            return Color(uiColor: .secondarySystemGroupedBackground)
            #else
            return Color.gray.opacity(0.1)
            #endif
        }()

        /// 次级背景（Tag/Pill 用）。
        public static let chipBackground: Color = {
            #if canImport(UIKit)
            return Color(uiColor: .tertiarySystemFill)
            #else
            return Color.gray.opacity(0.15)
            #endif
        }()

        /// 分组标签颜色。
        public static let groupPill = Color.accentColor.opacity(0.15)
    }
}
