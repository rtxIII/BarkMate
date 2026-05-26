//
//  AgentRouter.swift
//  BarkService
//
//  Decides whether a parsed Bark push belongs to the Agent Dashboard or the
//  legacy-compatible History Timeline path.
//

import Foundation
import Models

public enum AgentRoute: Sendable, Equatable {
    case agent(AgentRouteContext)
    case memo(MemoSource)
}

public struct AgentRouteContext: Sendable, Equatable {
    public let agentID: String
    public let taskID: String?
    public let aggregateKey: String
    public let status: AgentStatus
}

public enum AgentRouter {
    public static func route(
        _ parsed: ParsedPush,
        memoSource: MemoSource = .incoming
    ) -> AgentRoute {
        guard let status = parsed.agentStatus else {
            return .memo(memoSource)
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

