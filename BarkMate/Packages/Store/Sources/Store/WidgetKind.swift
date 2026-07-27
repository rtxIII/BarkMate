//
//  WidgetKind.swift
//  Store
//

import Foundation

/// Widget timeline kind 标识。Widget 声明与 NSE / 主 app 的
/// `WidgetCenter.reloadTimelines(ofKind:)` 必须引用同一常量,避免字符串漂移。
public enum WidgetKind {
    /// Active Agents 摘要 widget（systemSmall / systemMedium / 锁屏 accessory）。
    public static let activeAgents: String = "ActiveAgentsWidget"
}
