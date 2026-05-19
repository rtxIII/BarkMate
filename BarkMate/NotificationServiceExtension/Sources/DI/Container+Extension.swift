//
//  Container+Extension.swift
//  NotificationServiceExtension
//
//  Extension 进程的 Factory 注册。与主 App 隔离，需独立注册。
//

import Foundation
import Factory
import SwiftData
import Store

extension Container {

    /// 共享 SwiftData ModelContainer（与主 App 通过 App Group 同 URL）。
    var sharedModelContainer: Factory<ModelContainer> {
        self {
            do {
                return try SharedModelContainer.make()
            } catch {
                fatalError("Failed to create shared ModelContainer: \(error)")
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
