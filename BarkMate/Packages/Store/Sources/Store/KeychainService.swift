//
//  KeychainService.swift
//  Store
//
//  共享 Keychain 封装。主 App 与 NotificationServiceExtension 通过
//  `kSecAttrAccessGroup` 共享加密密钥；附件/小组件 target 不涉及密钥读取。
//
//  accessGroup 需使用完整值 `<TeamID>.com.barkagent.shared`；
//  Team ID 运行时由调用方注入（见 `Configuration`），避免硬编码。
//

import Foundation
import Security

public enum KeychainService {

    /// Keychain 访问组配置。传 nil 即使用默认 keychain（测试用）。
    public struct Configuration: Sendable {
        public let accessGroup: String?
        public let service: String

        public init(accessGroup: String?, service: String = "com.barkmate.shared") {
            self.accessGroup = accessGroup
            self.service = service
        }

        /// 生产配置：需调用方在启动时注入 Team ID。
        public static func shared(teamID: String) -> Configuration {
            Configuration(accessGroup: "\(teamID).com.barkagent.shared")
        }

        /// 测试/预览配置：不使用 access group，走本地 keychain。
        public static let inMemory = Configuration(accessGroup: nil)
    }

    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case itemEncodingFailed
    }

    public static func set(
        _ data: Data,
        forKey key: String,
        configuration: Configuration
    ) throws {
        var query = baseQuery(key: key, configuration: configuration)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateQuery = baseQuery(key: key, configuration: configuration)
            let attributes: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainError.unexpectedStatus(status)
            }
        default:
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    public static func get(
        forKey key: String,
        configuration: Configuration
    ) throws -> Data? {
        var query = baseQuery(key: key, configuration: configuration)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public static func delete(
        forKey key: String,
        configuration: Configuration
    ) throws {
        let query = baseQuery(key: key, configuration: configuration)
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func baseQuery(
        key: String,
        configuration: Configuration
    ) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: configuration.service,
            kSecAttrAccount as String: key
        ]
        if let accessGroup = configuration.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
