//
//  MissionControl+Spacing.swift
//  DesignSystem
//
//  Mission Control 间距与圆角令牌。
//
//  间距 ramp 与 mock B 的栅格一致:32px 主栅格 + 4 的倍数。
//  圆角默认偏锐,圆形元素只用在 Dynamic Island 等系统组件。
//

import SwiftUI

extension MissionControl {

    /// 间距 ramp(4 的倍数,与 32px 主栅格对齐)。
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let xl: CGFloat = 14
        public static let xxl: CGFloat = 16
        public static let xxxl: CGFloat = 18
        public static let huge: CGFloat = 22
        public static let giant: CGFloat = 32

        /// 卡片内 padding(深底大卡)。
        public static let cardInner: CGFloat = 14

        /// 卡片之间垂直 gap。
        public static let cardGap: CGFloat = 10

        /// 屏幕水平 padding(390pt 设备)。
        public static let screenHorizontal: CGFloat = 16

        /// Section header 与下方内容的垂直距离。
        public static let sectionAfterHeader: CGFloat = 8

        /// Section 与上一 section 的垂直距离。
        public static let sectionGap: CGFloat = 18

        /// Heads-up 大面板内 triage 三栏 cell 之间的 gap。
        public static let triageGap: CGFloat = 8

        /// Tab bar 与 content 之间的垂直 padding。
        public static let tabBarBottom: CGFloat = 16

        /// L 形角标长度(d-hero / lock-card 的装饰角)。
        public static let bracketCornerSize: CGFloat = 24
    }

    /// 圆角令牌。Mission Control 默认锐角(0),圆角只在 Island / Toggle / 进度条等少数地方。
    public enum Radius {
        /// 默认无圆角(战术风基线)。
        public static let none: CGFloat = 0

        /// 极小圆角,徽章 / chip 边角微调。
        public static let bracket: CGFloat = 1

        /// 小圆角,toggle / 进度条端点。
        public static let pip: CGFloat = 2

        /// 标准卡片(虽然 Mission Control 主体走锐角,某些组件如锁屏 lock-card 仍需 1-2pt)。
        public static let card: CGFloat = 0

        /// 圆形/胶囊,Dynamic Island、battery。
        public static let pill: CGFloat = 999

        /// Phone bezel 圆角(仅用于 Mock 预览)。
        public static let bezel: CGFloat = 48

        /// Screen 内圆角(仅用于 Mock 预览)。
        public static let screen: CGFloat = 38
    }

    /// 描边宽度。
    public enum Border {
        /// 1pt 主描边。
        public static let hairline: CGFloat = 1

        /// 1.5pt 强调描边(用于 active section / focused)。
        public static let strong: CGFloat = 1.5

        /// 2pt L 形角标描边(d-hero / lock-card 装饰)。
        public static let bracket: CGFloat = 2

        /// 状态条左侧粗 marker(大卡的颜色条)。
        public static let statusMarker: CGFloat = 4
    }

    /// 投影令牌。深底战术风很少用投影,主要用 glow shadow。
    public enum Shadow {
        public static let glowRadius: CGFloat = 12
        public static let glowOffsetY: CGFloat = 0
    }
}
