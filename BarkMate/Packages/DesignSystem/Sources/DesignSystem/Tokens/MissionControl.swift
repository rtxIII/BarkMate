//
//  MissionControl.swift
//  DesignSystem
//
//  Mission Control 视觉系统的入口命名空间。
//
//  与 `BarkTheme` 并列存在,不替换。旧组件(暖纸杂志风)继续用 BarkTheme;
//  Mock B(战术控制台风)的新屏与改造组件统一用 MissionControl.*。
//
//  视觉契约来源:doc/mock/screens-b-missioncontrol.html
//

import SwiftUI

/// Mission Control 视觉系统根命名空间。
///
/// 子模块:
/// - `MissionControl.Color`   色板:深底 + 琥珀/青/酸橙/橙/品红 HUD 调色板
/// - `MissionControl.Font`    字体:JetBrains Mono + Inter Tight + Instrument Serif
/// - `MissionControl.Spacing` 间距 ramp 与卡片 padding
/// - `MissionControl.Radius`  圆角(战术风默认锐角,圆角只用在 island 等系统元素)
/// - `MissionControl.Border`  边框 / hairline / glow 描边
/// - `MissionControl.Status`  AgentStatus 渲染映射(`[ WAIT ]` 方括号码 + 颜色绑定)
public enum MissionControl {
    /// token 版本号,用于运行期判断兼容性。
    public static let tokenVersion: String = "0.1.0"
}
