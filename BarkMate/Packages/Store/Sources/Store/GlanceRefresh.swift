//
//  GlanceRefresh.swift
//  Store
//

import WidgetKit

/// 统一的 glance 刷新入口。落库成功后调用,请求系统刷新 Widget timeline。
/// NSE 与主 app 各落库点共用此工具,避免 reloadTimelines 调用散落 / kind 漂移。
public enum GlanceRefresh {
    /// 请求刷新 Active Agents widget。请求非保证——系统按预算合并刷新,
    /// 高频推送不会 1:1 触发;失败静默,不影响调用方主流程。
    public static func reload() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.activeAgents)
    }
}
