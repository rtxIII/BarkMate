//
//  Container+Extension.swift
//  NotificationServiceExtension
//
//  Extension 进程的 Factory 注册。与主 App 隔离，需独立注册。
//

import Foundation
import os
import Factory
import SwiftData
import Store

extension Container {

    /// 共享 SwiftData ModelContainer（与主 App 通过 App Group 同 URL）。
    /// Extension 启动失败时降级到 in-memory 以保证 contentHandler 仍能完成,
    /// 让用户至少看到系统 banner;此次推送不会归档。
    var sharedModelContainer: Factory<ModelContainer> {
        self {
            let log = Logger(subsystem: "com.barkagent.ios", category: "nse")
            do {
                return try SharedModelContainer.make()
            } catch {
                log.fault("Extension shared container failed, falling back to in-memory: \(error.localizedDescription, privacy: .public)")
                NotificationStatusStore().save(
                    NotificationStatus(
                        kind: .storageUnavailable,
                        detail: "Notification extension could not open shared storage."
                    )
                )
                do {
                    return try SharedModelContainer.makeInMemory()
                } catch {
                    fatalError("Both shared and in-memory ModelContainer init failed: \(error)")
                }
            }
        }
        .singleton
    }

    /// Keychain 访问组配置。
    var keychainConfiguration: Factory<KeychainService.Configuration> {
        self {
            let teamID = Bundle.main.teamIdentifier ?? ""
            return .shared(teamID: teamID)
        }
        .singleton
    }
}

private extension Bundle {
    var teamIdentifier: String? {
        guard let prefix = object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String else {
            return nil
        }
        return prefix.hasSuffix(".") ? String(prefix.dropLast()) : prefix
    }
}
