//
//  AgentTask+Stale.swift
//  Models
//
//  Stale 派生:running 且 updatedAt 超过阈值 → .stale。不落库,视图渲染时惰性计算。
//

import Foundation

extension AgentTask {
    /// 派生有效状态。仅 running 且 `now - updatedAt` 严格超过阈值时返回 `.stale`,其余原样。
    public func effectiveStatus(now: Date, threshold: StaleThreshold) -> AgentStatus {
        guard status == .running,
              let limit = threshold.seconds,
              now.timeIntervalSince(updatedAt) > limit
        else { return status }
        return .stale
    }
}
