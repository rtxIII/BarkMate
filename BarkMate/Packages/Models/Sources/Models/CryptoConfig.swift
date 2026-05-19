//
//  CryptoConfig.swift
//  Models
//

import Foundation
import SwiftData

/// 加密配置（密钥和 IV 存在 Keychain，此处仅存元数据与引用）。
@Model
public final class CryptoConfig {
    @Attribute(.unique) public var id: UUID
    public var serverID: UUID
    public var algorithmRaw: String
    public var modeRaw: String
    /// Keychain 中密钥的 account 引用。
    public var keychainKeyRef: String
    /// Keychain 中 IV 的 account 引用（ECB 模式无需 IV）。
    public var keychainIVRef: String?
    public var isEnabled: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        serverID: UUID,
        algorithm: CryptoAlgorithm = .aes256,
        mode: CryptoMode = .cbc,
        keychainKeyRef: String,
        keychainIVRef: String? = nil,
        isEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.serverID = serverID
        self.algorithmRaw = algorithm.rawValue
        self.modeRaw = mode.rawValue
        self.keychainKeyRef = keychainKeyRef
        self.keychainIVRef = keychainIVRef
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
}

extension CryptoConfig {
    public var algorithm: CryptoAlgorithm {
        get { CryptoAlgorithm(rawValue: algorithmRaw) ?? .aes256 }
        set { algorithmRaw = newValue.rawValue }
    }

    public var mode: CryptoMode {
        get { CryptoMode(rawValue: modeRaw) ?? .cbc }
        set { modeRaw = newValue.rawValue }
    }
}
