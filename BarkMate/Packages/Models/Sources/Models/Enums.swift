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

/// Running task 超时判定阈值。`.off` = 关闭 stale 推断。
public enum StaleThreshold: Equatable, Hashable, Sendable {
    case off
    case minutes(Int)

    /// 秒数;`.off` 无阈值返回 nil。
    public var seconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .minutes(let m): return TimeInterval(m * 60)
        }
    }

    /// Settings 行 / picker 展示文案。
    public var displayLabel: String {
        switch self {
        case .off: return "off"
        case .minutes(let m): return "\(m) min"
        }
    }
}

public enum StaleThresholdCatalog {
    /// Settings picker 档位。
    public static let options: [StaleThreshold] =
        [.off, .minutes(10), .minutes(30), .minutes(60), .minutes(120)]

    /// 未配置时的默认阈值。
    public static let defaultThreshold: StaleThreshold = .minutes(30)
}
