//
//  CryptoSettingsStore.swift
//  BarkService
//
//  从 SwiftData + Keychain 组装 CryptoBundle。V1 取第一个 enabled 的配置（全局单配置）。
//  密钥/IV 通过 KeychainService 跨 App Group 共享给 NotifSvcExt。
//

import Foundation
import SwiftData
import Models
import Store

public struct CryptoSettingsStore {

    private let modelContainer: ModelContainer
    private let keychainConfig: KeychainService.Configuration

    public init(
        modelContainer: ModelContainer,
        keychainConfig: KeychainService.Configuration
    ) {
        self.modelContainer = modelContainer
        self.keychainConfig = keychainConfig
    }

    /// 读取当前激活的加密配置；未配置返回 nil。
    public func currentBundle() throws -> CryptoBundle? {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        var descriptor = FetchDescriptor<CryptoConfig>(
            predicate: #Predicate<CryptoConfig> { $0.isEnabled }
        )
        descriptor.fetchLimit = 1
        guard let config = try context.fetch(descriptor).first else {
            return nil
        }

        guard let key = try KeychainService.get(
            forKey: config.keychainKeyRef,
            configuration: keychainConfig
        ) else {
            return nil
        }

        let iv: Data
        if let ref = config.keychainIVRef,
           let stored = try KeychainService.get(forKey: ref, configuration: keychainConfig) {
            iv = stored
        } else {
            iv = Data()
        }

        // V1 默认 PKCS7 padding（CryptoConfig 模型目前未存 padding，V2 扩展）。
        return CryptoBundle(
            algorithm: config.algorithm,
            mode: config.mode,
            padding: .pkcs7,
            key: key,
            iv: iv
        )
    }
}
