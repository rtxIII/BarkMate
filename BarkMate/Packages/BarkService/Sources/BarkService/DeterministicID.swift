//
//  DeterministicID.swift
//  BarkService
//
//  字符串 → 稳定 UUID。供 PushParser 的 id fallback 与 PushArchiver 的
//  AgentStep / Memo 幂等去重共享,保证同一 push 内容跨 NSE 调用产生同一 UUID。
//
//  算法:SHA256 取前 16 字节,设置 RFC 4122 version 4 + variant 标志位。
//

import Foundation
import CryptoKit

/// 将任意字符串映射到稳定 UUID(SHA256 截 16 字节 + RFC4122 标志位)。
/// 相同输入永远产生相同 UUID。
internal func deterministicUUID(from input: String) -> UUID {
    let digest = SHA256.hash(data: Data(input.utf8))
    var bytes = Array(digest.prefix(16))
    bytes[6] = (bytes[6] & 0x0F) | 0x40 // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80 // variant 10
    return UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11],
        bytes[12], bytes[13], bytes[14], bytes[15]
    ))
}
