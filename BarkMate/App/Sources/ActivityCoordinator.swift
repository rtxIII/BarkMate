//
//  ActivityCoordinator.swift
//  BarkAgent
//
//  线 C(本地链 P0):主 app 侧 Live Activity 协调器。
//  只有主 app 能 `Activity.request`(NSE 不能)。订阅 Darwin `.itemDidArrive`,
//  每次落库后按 ActivityPolicy 起/停 LA,并把 activity.id 写回 AgentTask.liveActivityID。
//
//  边界:app 被系统完全杀掉时本协调器不跑 → 冷态更新走 G3.4 远程 push(P1)。
//

import Foundation
import SwiftData
import ActivityKit
import Models
import Store
import BarkService

@MainActor
final class ActivityCoordinator {

    private let modelContainer: ModelContainer
    private let barkClient: BarkClientProtocol
    private var darwinObserver: DarwinObserver?
    /// 每个活跃 LA 的 push-token 观察任务，key = activity.id。end 时取消，避免泄漏。
    private var tokenObservers: [String: Task<Void, Never>] = [:]

    nonisolated init(modelContainer: ModelContainer, barkClient: BarkClientProtocol) {
        self.modelContainer = modelContainer
        self.barkClient = barkClient
    }

    /// 启动监听 + 立刻核对一次。
    func start() {
        Task { await reconcile() }

        guard darwinObserver == nil else { return }
        darwinObserver = DarwinNotification.observe(.itemDidArrive) { @Sendable in
            Task { @MainActor [weak self] in
                await self?.reconcile()
            }
        }
    }

    /// 核对任务状态与实际活跃 LA,按 ActivityPolicy 起/停。
    func reconcile() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let context = ModelContext(modelContainer)
        guard let tasks = try? context.fetch(FetchDescriptor<AgentTask>()) else { return }

        // 1. 清理系统已消解(用户划掉 / 超时)的 LA 留下的悬空 liveActivityID。
        let activeIDs = Set(Activity<AgentActivityAttributes>.activities.map(\.id))
        for task in tasks {
            if let laID = task.liveActivityID, !activeIDs.contains(laID) {
                task.liveActivityID = nil
            }
        }

        // 2. 纯决策。
        let snapshots = tasks.map {
            ActivityPolicy.TaskSnapshot(
                id: $0.id,
                status: $0.status,
                isArchived: $0.isArchived,
                updatedAt: $0.updatedAt,
                hasActivity: $0.liveActivityID != nil
            )
        }
        let plan = ActivityPolicy.plan(tasks: snapshots)
        guard !plan.toStart.isEmpty || !plan.toEnd.isEmpty || !plan.toUpdate.isEmpty else {
            try? context.save()   // 可能只清理了悬空 id
            return
        }

        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // 3. 先 end(腾出 cap),再 update 已有 LA,最后 start 新的。
        for id in plan.toEnd {
            guard let task = byID[id] else { continue }
            await endActivity(for: task)
        }
        for id in plan.toUpdate {
            guard let task = byID[id] else { continue }
            await updateActivity(for: task)
        }
        for id in plan.toStart {
            guard let task = byID[id] else { continue }
            startActivity(for: task)
        }

        try? context.save()
    }

    // MARK: - ActivityKit 执行

    private func startActivity(for task: AgentTask) {
        let attributes = AgentActivityAttributes(
            agentID: task.agentID,
            displayName: task.displayName,
            iconURL: task.iconURL
        )
        let state = AgentActivityAttributes.ContentState(
            status: task.status,
            stepTitle: task.latestStepTitle ?? "",
            progress: task.progress
        )
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: .token
            )
            task.liveActivityID = activity.id
            observePushToken(for: activity, aggregateKey: task.aggregateKey)
        } catch {
            BarkLog.lifecycle.error("LA request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateActivity(for task: AgentTask) async {
        guard let laID = task.liveActivityID else { return }
        let state = AgentActivityAttributes.ContentState(
            status: task.status,
            stepTitle: task.latestStepTitle ?? "",
            progress: task.progress
        )
        for activity in Activity<AgentActivityAttributes>.activities where activity.id == laID {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func endActivity(for task: AgentTask) async {
        if let laID = task.liveActivityID {
            for activity in Activity<AgentActivityAttributes>.activities where activity.id == laID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            tokenObservers.removeValue(forKey: laID)?.cancel()
        }
        // 注销服务端登记，避免任务结束后仍被 fan-out。
        await reportLiveActivityToken("deleted", aggregateKey: task.aggregateKey)
        task.liveActivityID = nil
    }

    // MARK: - Push-token fan-out 登记

    /// 观察某 Activity 的 push token 更新，逐个上报服务端。
    private func observePushToken(
        for activity: Activity<AgentActivityAttributes>,
        aggregateKey: String
    ) {
        let id = activity.id
        tokenObservers[id]?.cancel()
        tokenObservers[id] = Task { [weak self] in
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                await self?.reportLiveActivityToken(token, aggregateKey: aggregateKey)
            }
        }
    }

    /// 向所有已注册（key 非空）的服务器登记 / 注销该任务的 LA token。
    /// 推送落库不写 `sourceServerID`，故无法定位单一来源服务器；改为全量登记，
    /// 每台服务器仅在自己 KV 命中该 aggregateKey 时才会 fan-out，冗余登记无副作用。
    private func reportLiveActivityToken(_ token: String, aggregateKey: String) async {
        let context = ModelContext(modelContainer)
        let servers = (try? context.fetch(FetchDescriptor<Server>())) ?? []
        for server in servers where !server.key.isEmpty {
            guard let url = URL(string: server.address) else { continue }
            do {
                try await barkClient.registerLiveActivity(
                    token: token,
                    aggregateKey: aggregateKey,
                    serverURL: url,
                    deviceKey: server.key
                )
            } catch {
                BarkLog.push.error("LA token report failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
