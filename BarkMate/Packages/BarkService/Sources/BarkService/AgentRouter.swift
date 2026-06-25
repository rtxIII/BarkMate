//
//  AgentRouter.swift
//  BarkService
//
//  Decides whether a parsed Bark push belongs to the Agent Dashboard or the
//  legacy History → Incoming inbox path (旧 Bark 协议无 agent_status 字段)。
//

import Foundation
import Models

public enum AgentRoute: Sendable, Equatable {
    case agent(AgentRouteContext)
    /// 无 agent_status 字段 → 归入 AgentInboxItem，mock B 的 History → Incoming 段。
    case inbox
}

public struct AgentRouteContext: Sendable, Equatable {
    public let agentID: String
    public let taskID: String?
    public let aggregateKey: String
    public let status: AgentStatus
}

public enum AgentRouter {
    public static func route(_ parsed: ParsedPush) -> AgentRoute {
        guard let status = parsed.agentStatus else {
            return .inbox
        }

        let agentID = parsed.agentID
        let taskID = parsed.taskID
        return .agent(
            AgentRouteContext(
                agentID: agentID,
                taskID: taskID,
                aggregateKey: AgentTask.aggregateKey(agentID: agentID, taskID: taskID),
                status: status
            )
        )
    }
}
