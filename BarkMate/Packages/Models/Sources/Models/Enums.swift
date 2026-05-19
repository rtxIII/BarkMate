//
//  Enums.swift
//  Models
//

import Foundation

public enum AgentStatus: String, Codable, Sendable, CaseIterable {
    case running
    case waitingInput = "waiting_input"
    case blocked
    case done
    case failed
    /// 客户端推断：> N 分钟无更新且仍为 running。
    case stale
}

public enum MemoSource: String, Codable, Sendable, CaseIterable {
    /// 用户手写 / Share Extension。
    case manual
    /// 旧 Bark 协议推送（无 agent_status 字段）—— 落入 Memo 表。
    case incoming
}

public enum BodyType: String, Codable, Sendable, CaseIterable {
    case plainText
    case markdown
}

public enum ServerState: String, Codable, Sendable, CaseIterable {
    case pending
    case ok
    case error
}

public enum CryptoAlgorithm: String, Codable, Sendable, CaseIterable {
    case aes128
    case aes192
    case aes256
}

public enum CryptoMode: String, Codable, Sendable, CaseIterable {
    case cbc
    case ecb
    case gcm
}

public enum CryptoPadding: String, Codable, Sendable, CaseIterable {
    case pkcs7
    case noPadding
}
