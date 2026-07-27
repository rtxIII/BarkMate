//
//  ActivityPolicy.swift
//  BarkAgent
//
//  线 C(本地链 P0):Live Activity 启停的纯决策。
//  刻意不依赖 ActivityKit / SwiftData —— 只吃任务快照,吐起停计划,
//  便于对 cap / LRU / 状态映射做确定性单测(见 G3.5)。
//
//  规则(方案 X):
//   - 只为 needsYou(waiting_input / blocked)且未归档的任务起 LA。
//   - desired = 这些任务按 updatedAt 倒序取前 maxActive(即 cap + LRU:
//     更新的挤掉更旧的)。
//   - 有 LA 但不在 desired(离开 needsYou / 归档 / 被挤出)→ end。
//   - 在 desired 但还没 LA → start。
//   - 在 desired 且已有 LA → update(把 content state 刷到最新)。
//  说明:stale 仅由 running 派生,而 LA 只起于 waiting/blocked,故此处用原始
//  status 即可,不涉及 stale 派生。
//  更新只能在主 app 进程做:NSE 是独立进程,Activity.activities 恒为空,无法
//  update(已验证)。故本地链更新走前台 coordinator;挂起/被杀走 G3.4 远程 push。
//

import Foundation
import Models

enum ActivityPolicy {

    /// 同时活跃 LA 上限。
    static let maxActive = 4

    /// 决策输入:任务的最小快照(与 ActivityKit / SwiftData 解耦)。
    struct TaskSnapshot: Equatable {
        let id: UUID
        let status: AgentStatus
        let isArchived: Bool
        let updatedAt: Date
        /// 该任务当前是否已关联一个（经协调器核对后仍活跃的）LA。
        let hasActivity: Bool

        init(id: UUID, status: AgentStatus, isArchived: Bool, updatedAt: Date, hasActivity: Bool) {
            self.id = id
            self.status = status
            self.isArchived = isArchived
            self.updatedAt = updatedAt
            self.hasActivity = hasActivity
        }
    }

    struct Plan: Equatable {
        var toStart: [UUID] = []
        var toEnd: [UUID] = []
        var toUpdate: [UUID] = []
    }

    /// 是否属于「需要你介入」——LA 只起于此。
    static func isNeedsYou(_ status: AgentStatus) -> Bool {
        status == .waitingInput || status == .blocked
    }

    static func plan(tasks: [TaskSnapshot]) -> Plan {
        let desired = tasks
            .filter { !$0.isArchived && isNeedsYou($0.status) }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(maxActive)
        let desiredIDs = Set(desired.map(\.id))

        var plan = Plan()
        for task in tasks where task.hasActivity && !desiredIDs.contains(task.id) {
            plan.toEnd.append(task.id)
        }
        for task in desired {
            if task.hasActivity {
                // 保留 LA 的任务:刷新 content state 到最新(前台链更新)。
                plan.toUpdate.append(task.id)
            } else {
                plan.toStart.append(task.id)
            }
        }
        return plan
    }
}
