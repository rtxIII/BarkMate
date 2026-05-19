//
//  DecryptProcessor.swift
//  BarkService
//
//  Bark 加密推送解密。协议参考 doc/bark-protocol.md §3。
//  - 无 ciphertext: 直通
//  - 有 ciphertext + 成功: 清理 ciphertext/iv 字段，合并解密出的 JSON 字段并重建 aps
//  - 有 ciphertext + 失败: 保留原 ciphertext，body = "Decryption Failed"
//

import Foundation
import CryptoSwift
import Models

public enum DecryptProcessor {

    public struct DecryptResult: @unchecked Sendable {
        public let userInfo: [AnyHashable: Any]
        public let decryptionFailed: Bool
        public let originalCiphertext: String?
        public let originalIV: String?

        public init(
            userInfo: [AnyHashable: Any],
            decryptionFailed: Bool = false,
            originalCiphertext: String? = nil,
            originalIV: String? = nil
        ) {
            self.userInfo = userInfo
            self.decryptionFailed = decryptionFailed
            self.originalCiphertext = originalCiphertext
            self.originalIV = originalIV
        }
    }

    /// 主入口：检查是否有 ciphertext；有则尝试解密，失败走降级。
    public static func decryptIfNeeded(
        userInfo: [AnyHashable: Any],
        bundle: CryptoBundle?
    ) -> DecryptResult {
        guard let ciphertext = userInfo["ciphertext"] as? String, !ciphertext.isEmpty else {
            return DecryptResult(userInfo: userInfo)
        }

        let ivOverride = userInfo["iv"] as? String

        guard let bundle else {
            return failureResult(userInfo: userInfo, ciphertext: ciphertext, ivOverride: ivOverride)
        }

        let effectiveBundle: CryptoBundle
        if let ivOverride, let ivData = ivOverride.data(using: .utf8) {
            effectiveBundle = bundle.overriding(iv: ivData)
        } else {
            effectiveBundle = bundle
        }

        do {
            let decryptedDict = try decrypt(ciphertext: ciphertext, bundle: effectiveBundle)
            let merged = merge(decryptedDict: decryptedDict, into: userInfo)
            return DecryptResult(userInfo: merged)
        } catch {
            return failureResult(userInfo: userInfo, ciphertext: ciphertext, ivOverride: ivOverride)
        }
    }

    // MARK: - Internals

    static func decrypt(ciphertext: String, bundle: CryptoBundle) throws -> [String: Any] {
        let cipherBytes: [UInt8] = Array(base64: ciphertext)
        let aes = try AES(
            key: [UInt8](bundle.key),
            blockMode: blockMode(for: bundle),
            padding: padding(for: bundle.padding)
        )
        let plainBytes = try aes.decrypt(cipherBytes)
        let plaintext = String(bytes: plainBytes, encoding: String.Encoding.utf8) ?? ""

        guard
            let data = plaintext.data(using: String.Encoding.utf8),
            let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw DecryptError.invalidJSON
        }
        return parsed
    }

    private static func blockMode(for bundle: CryptoBundle) throws -> BlockMode {
        let ivBytes = [UInt8](bundle.iv)
        switch bundle.mode {
        case .cbc:
            return CBC(iv: ivBytes)
        case .ecb:
            return ECB()
        case .gcm:
            return GCM(iv: ivBytes, mode: .combined)
        }
    }

    private static func padding(for padding: CryptoPadding) -> Padding {
        switch padding {
        case .pkcs7:
            return .pkcs7
        case .noPadding:
            return .noPadding
        }
    }

    /// 合并解密出的 dict 到 userInfo：小写键、重建 aps（title/subtitle/body → aps.alert）。
    private static func merge(
        decryptedDict: [String: Any],
        into userInfo: [AnyHashable: Any]
    ) -> [AnyHashable: Any] {
        var merged: [AnyHashable: Any] = userInfo
        merged.removeValue(forKey: "ciphertext")
        merged.removeValue(forKey: "iv")

        var alert: [String: Any] = [:]
        for (rawKey, value) in decryptedDict {
            let key = rawKey.lowercased()
            switch key {
            case "title", "subtitle", "body":
                alert[key] = value
                merged[key] = value
            default:
                merged[key] = value
            }
        }

        if !alert.isEmpty {
            merged["aps"] = ["alert": alert]
        }
        return merged
    }

    private static func failureResult(
        userInfo: [AnyHashable: Any],
        ciphertext: String,
        ivOverride: String?
    ) -> DecryptResult {
        var mutated = userInfo
        mutated["aps"] = [
            "alert": ["body": "Decryption Failed"]
        ]
        return DecryptResult(
            userInfo: mutated,
            decryptionFailed: true,
            originalCiphertext: ciphertext,
            originalIV: ivOverride
        )
    }

    enum DecryptError: Error, Equatable {
        case invalidJSON
    }
}
