//
//  AgentTask+Stale.swift
//  Models
//
//  Stale 派生:running 或 waiting_input 且 updatedAt 超过阈值 → .stale。
//  不落库,视图渲染时惰性计算。
//

import Foundation

extension AgentTask {
    /// 派生有效状态。running 或 waitingInput 且 `now - updatedAt` 严格超过阈值时返回 `.stale`,其余原样。
    ///
    /// waiting_input 纳入老化的原因:它是"粘滞"状态——Notification hook 在 agent 需要
    /// 权限/输入时发一条 waiting_input,用户在终端答复后并无续发推送覆盖该卡(客户端侧
    /// 对 waiting 零自清),于是陈年 WAIT 会持续堆在 "Needs you" 段。超阈值后降级为 stale
    /// (归入 Running 段的灰色 [ STALE ]),不再霸占 "Needs you"。
    public func effectiveStatus(now: Date, threshold: StaleThreshold) -> AgentStatus {
        guard status == .running || status == .waitingInput,
              let limit = threshold.seconds,
              now.timeIntervalSince(updatedAt) > limit
        else { return status }
        return .stale
    }
}
