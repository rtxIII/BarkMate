//
//  DemoPushInjector.swift
//  BarkService
//
//  本地 demo push 注入器:绕过 APNs / NSE,直接通过 PushArchiver 写一条
//  v0.3 mock push 进 SwiftData,触发 @Query 刷新。供 Dashboard 的 toolbar
//  bolt 与 Setup tab 的 "Send demo push" 按钮共用,避免逻辑分叉。
//
//  - 同 aggregate(demo-agent::demo-task)递增 progress
//  - 第 totalSteps 步翻 done
//  - 写 SwiftData 后立刻发 itemDidArrive Darwin 通知
//

import Foundation
import SwiftData
import Models

public enum DemoPushInjector {

    public static let agentID = "demo-agent"
    public static let taskID = "demo-task"
    public static let totalSteps = 7

    /// 推一步。返回新 step 序号(1-based)与是否到了终态。
    @MainActor
    @discardableResult
    public static func injectNextStep(into container: ModelContainer) -> (step: Int, isFinal: Bool) {
        let context = container.mainContext
        let aggregate = AgentTask.aggregateKey(agentID: agentID, taskID: taskID)
        let predicate = #Predicate<AgentTask> { $0.aggregateKey == aggregate }
        let existing = (try? context.fetch(FetchDescriptor<AgentTask>(predicate: predicate)).first)

        let nextStep: Int
        if let progress = existing?.progress,
           let slash = progress.firstIndex(of: "/"),
           let current = Int(progress[..<slash]) {
            nextStep = min(current + 1, totalSteps)
        } else {
            nextStep = 1
        }
        let isFinal = nextStep >= totalSteps

        let parsed = ParsedPush(
            id: "demo-push-\(UUID().uuidString)",
            title: isFinal ? "Demo task complete" : "Demo step \(nextStep)",
            body: isFinal
                ? "All \(totalSteps) demo steps passed."
                : "Step \(nextStep) of \(totalSteps): mock progress",
            group: agentID,
            agentStatus: isFinal ? .done : .running,
            taskID: taskID,
            progress: "\(nextStep)/\(totalSteps)"
        )
        do {
            let archiver = PushArchiver(modelContainer: container)
            try archiver.archive(parsed)
        } catch {
            // 不阻断 UI;异常仅在 console 输出,真实推送场景不会触发(单线程 + 短事务)。
            print("[DemoPushInjector] archive failed: \(error)")
        }
        return (nextStep, isFinal)
    }
}
