//
//  PushArchiver.swift
//  BarkService
//
//  ParsedPush → SwiftData AgentTask/AgentStep/AgentInboxItem 入库。
//  身处 Extension 24MB 内存约束下：
//    - 使用临时 ModelContext（不复用 mainContext）
//    - 短事务、立即 save
//    - Agent 路径按 aggregateKey upsert task，每次推送新增 step
//    - Inbox 路径按 parsed.id 幂等写入 AgentInboxItem（旧 Bark 协议落点）
//

import Foundation
import SwiftData
import Models

public struct PushArchiver {

    private let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// 将 ParsedPush 落库为 AgentTask/AgentStep 或 AgentInboxItem。
    /// 返回 AgentTask.id 或 AgentInboxItem.id（UUID）。
    ///
    /// - Parameters:
    ///   - parsed: 解析后的 push 内容
    ///   - degradation: 解密失败时传入，密文/IV 会序列化到 `AgentInboxItem.metadata`
    ///     便于后续手动解密恢复（2.12 降级策略）。
    @discardableResult
    public func archive(
        _ parsed: ParsedPush,
        degradation: DecryptProcessor.DecryptResult? = nil
    ) throws -> UUID {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        switch AgentRouter.route(parsed) {
        case .agent(let route):
            return try upsertAgentTask(parsed, route: route, context: context)
        case .inbox:
            return try archiveInboxItem(
                parsed,
                degradation: degradation,
                context: context
            )
        }
    }

    private func upsertAgentTask(
        _ parsed: ParsedPush,
        route: AgentRouteContext,
        context: ModelContext
    ) throws -> UUID {
        let aggregateKey = route.aggregateKey
        let predicate = #Predicate<AgentTask> { $0.aggregateKey == aggregateKey }
        let existing = try context.fetch(FetchDescriptor<AgentTask>(predicate: predicate)).first

        let task: AgentTask
        if let existing {
            task = existing
            existing.displayName = route.agentID
            existing.iconURL = parsed.iconURL ?? existing.iconURL
            existing.status = route.status
            existing.latestStepTitle = parsed.title ?? existing.latestStepTitle
            existing.progress = parsed.progress ?? existing.progress
            existing.eta = parsed.eta ?? existing.eta
            existing.sourceServerID = parsed.sourceServerID ?? existing.sourceServerID
            existing.updatedAt = parsed.createdAt
        } else {
            task = AgentTask(
                aggregateKey: route.aggregateKey,
                agentID: route.agentID,
                taskID: route.taskID,
                displayName: route.agentID,
                iconURL: parsed.iconURL,
                status: route.status,
                latestStepTitle: parsed.title,
                progress: parsed.progress,
                eta: parsed.eta,
                sourceServerID: parsed.sourceServerID,
                createdAt: parsed.createdAt,
                updatedAt: parsed.createdAt
            )
            context.insert(task)
        }

        // Step 用 deterministicUUID(from: parsed.id) 保证 APNs 重传同一 push 时
        // step 不重复插入(C1 修复)。fetch 检查 step.id 已存在则只更新 task 不插 step。
        let stepID = deterministicUUID(from: parsed.id)
        let stepPredicate = #Predicate<AgentStep> { $0.id == stepID }
        let stepExists = try context.fetch(FetchDescriptor<AgentStep>(predicate: stepPredicate)).first != nil

        if !stepExists {
            let step = AgentStep(
                id: stepID,
                status: route.status,
                title: parsed.title,
                body: parsed.body,
                bodyType: parsed.bodyType,
                progress: parsed.progress,
                url: parsed.url,
                imageURL: parsed.imageURL,
                rawPayload: encodeRawPayload(parsed),
                createdAt: parsed.createdAt
            )
            context.insert(step)
            task.steps.append(step)
        }

        try context.save()
        return task.id
    }

    private func archiveInboxItem(
        _ parsed: ParsedPush,
        degradation: DecryptProcessor.DecryptResult?,
        context: ModelContext
    ) throws -> UUID {
        let uuid = UUID(uuidString: parsed.id) ?? deterministicUUID(from: parsed.id)
        let predicate = #Predicate<AgentInboxItem> { $0.id == uuid }
        let existing = try context.fetch(FetchDescriptor<AgentInboxItem>(predicate: predicate)).first

        let metadata = encodeDegradationMetadata(degradation)

        if let existing {
            existing.title = parsed.title
            existing.body = parsed.body
            existing.bodyType = parsed.bodyType
            existing.group = parsed.group
            existing.url = parsed.url
            existing.imageURL = parsed.imageURL
            existing.sourceServerID = parsed.sourceServerID
            existing.updatedAt = parsed.createdAt
            if let metadata { existing.metadata = metadata }
            try context.save()
            return existing.id
        }

        let item = AgentInboxItem(
            id: uuid,
            title: parsed.title,
            body: parsed.body,
            bodyType: parsed.bodyType,
            group: parsed.group,
            sourceServerID: parsed.sourceServerID,
            url: parsed.url,
            imageURL: parsed.imageURL,
            metadata: metadata,
            createdAt: parsed.createdAt,
            updatedAt: parsed.createdAt
        )
        context.insert(item)
        try context.save()
        return item.id
    }

    private func encodeDegradationMetadata(
        _ result: DecryptProcessor.DecryptResult?
    ) -> Data? {
        guard
            let result,
            result.decryptionFailed,
            let ciphertext = result.originalCiphertext
        else { return nil }

        var payload: [String: String] = ["ciphertext": ciphertext, "reason": "decryptionFailed"]
        if let iv = result.originalIV { payload["iv"] = iv }
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    private func encodeRawPayload(_ parsed: ParsedPush) -> Data? {
        try? JSONEncoder().encode(parsed)
    }
}
