//
//  CryptoBundle.swift
//  BarkService
//
//  解密所需的完整参数集。通常由 CryptoSettingsStore 从 SwiftData + Keychain 组装。
//

import Foundation
import Models

public struct CryptoBundle: Sendable, Equatable {
    public let algorithm: CryptoAlgorithm
    public let mode: CryptoMode
    public let padding: CryptoPadding
    public let key: Data
    /// ECB 模式可为空 Data。CBC 需 16 字节；GCM 需 12 字节。
    public let iv: Data

    public init(
        algorithm: CryptoAlgorithm,
        mode: CryptoMode,
        padding: CryptoPadding,
        key: Data,
        iv: Data
    ) {
        self.algorithm = algorithm
        self.mode = mode
        self.padding = padding
        self.key = key
        self.iv = iv
    }

    /// 返回覆盖 iv 后的新 bundle（用于 payload 的 `iv` 字段覆盖）。
    public func overriding(iv: Data) -> CryptoBundle {
        CryptoBundle(algorithm: algorithm, mode: mode, padding: padding, key: key, iv: iv)
    }
}
