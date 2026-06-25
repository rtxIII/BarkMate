//
//  PushPipeline.swift
//  BarkService
//
//  NSE 接收到 APNs payload 后的纯函数管线。把 NotificationService.didReceive
//  里的 4 阶段(decrypt -> parse -> archive -> degrade) 抽成可测的 entry point:
//    process(userInfo:bundle:container:) async -> Outcome
//
//  NSE 只剩"把 userInfo / content 喂进来 + 同步明文 alert + 下载图片 + 发 Darwin
//  通知"这些 Notification-框架交互;实际 schema 决策与落库全在这里。
//
//  这样 simulator 跑不了真实 APNs / NSE 时,通过集成测试覆盖整条管线。
//

import Foundation
import SwiftData
import Models

public enum PushPipeline {

    /// 单次 push 的处理结果。Outcome 给 NSE 用于:
    ///   - 同步 alert(.archived / .pending 都已有解密后的 userInfo)
    ///   - 决定是否需要 Darwin 通知主 App(任意非 .skipped 都需要)
    public enum Outcome: Sendable {
        /// 成功落 SwiftData(走 Agent 路径或 Inbox 路径)。
        case archived(parsed: ParsedPush, decrypt: DecryptProcessor.DecryptResult, routeKind: RouteKind)
        /// SwiftData 不可用或落库失败,已入 PendingQueue。
        case pending(parsed: ParsedPush, decrypt: DecryptProcessor.DecryptResult)
        /// 入 PendingQueue 也失败(磁盘/编码错误);仅返回最大可恢复信息。
        case dropped(parsed: ParsedPush, decrypt: DecryptProcessor.DecryptResult, error: Error)

        public var decryptResult: DecryptProcessor.DecryptResult {
            switch self {
            case .archived(_, let r, _), .pending(_, let r), .dropped(_, let r, _):
                return r
            }
        }

        public var parsed: ParsedPush {
            switch self {
            case .archived(let p, _, _), .pending(let p, _), .dropped(let p, _, _):
                return p
            }
        }
    }

    public enum RouteKind: Sendable, Equatable {
        case agent
        /// 无 agent_status 字段 → 落 AgentInboxItem（mock B 的 History → Incoming 段）。
        case inbox
    }

    /// 同步处理一条 push payload。
    /// - Parameters:
    ///   - userInfo: APNs `userInfo`(已含 aps.alert 等字段)。
    ///   - bundle: 当前活跃的 CryptoBundle(无配置传 nil → 加密推送会走降级)。
    ///   - container: 可选 SwiftData ModelContainer。nil 时所有 push 都进 PendingQueue。
    ///   - queue: 可注入的 PendingQueue(测试用);生产传 nil 时默认 App Group 容器。
    public static func process(
        userInfo: [AnyHashable: Any],
        bundle: CryptoBundle?,
        container: ModelContainer?,
        queue: PendingQueue? = nil
    ) -> Outcome {
        let decrypt = DecryptProcessor.decryptIfNeeded(userInfo: userInfo, bundle: bundle)
        let parsed = PushParser.parse(userInfo: decrypt.userInfo)

        if let container {
            do {
                let archiver = PushArchiver(modelContainer: container)
                try archiver.archive(parsed, degradation: decrypt)
                let kind: RouteKind = (parsed.agentStatus != nil) ? .agent : .inbox
                return .archived(parsed: parsed, decrypt: decrypt, routeKind: kind)
            } catch {
                // archive 失败 → 降级到 PendingQueue。
            }
        }

        let effectiveQueue = queue ?? PendingQueue()
        do {
            try effectiveQueue.enqueue(parsed)
            return .pending(parsed: parsed, decrypt: decrypt)
        } catch {
            return .dropped(parsed: parsed, decrypt: decrypt, error: error)
        }
    }
}
