//
//  PendingQueueDrainer.swift
//  BarkMate
//
//  主 App 侧：启动时 + 收到 Darwin 通知时扫描 PendingQueue，逐条归档。
//  Extension 写 SwiftData 失败走的旁路，在此消费。
//

import Foundation
import SwiftData
import Models
import Store
import BarkService

@MainActor
final class PendingQueueDrainer {

    private let modelContainer: ModelContainer
    private let queue: PendingQueue
    private let archiver: PushArchiver
    private var darwinObserver: DarwinObserver?

    nonisolated init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.queue = PendingQueue()
        self.archiver = PushArchiver(modelContainer: modelContainer)
    }

    /// 启动监听 + 立刻跑一次 drain。
    func start() {
        Task { await drain() }

        guard darwinObserver == nil else { return }
        darwinObserver = DarwinNotification.observe(.itemDidArrive) { @Sendable in
            Task { @MainActor [weak self] in
                await self?.drain()
            }
        }
    }

    func drain() async {
        do {
            let pending = try queue.drain()
            if pending.isEmpty { return }

            for parsed in pending {
                do {
                    try archiver.archive(parsed)
                } catch {
                    print("[Drainer] archive failed for \(parsed.id): \(error.localizedDescription)")
                }
            }
            print("[Drainer] drained \(pending.count) pending message(s)")
        } catch {
            print("[Drainer] drain failed: \(error.localizedDescription)")
        }
    }
}
