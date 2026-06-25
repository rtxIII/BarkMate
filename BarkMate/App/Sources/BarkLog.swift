//
//  BarkLog.swift
//  BarkAgent
//
//  Release 静默的开发日志。生产构建里 dprint(...) 是空调用，
//  避免 APNs token、server key 等敏感片段进入 device console。
//

import Foundation
import os

/// Subsystem 用 bundle id 前缀，category 由调用方按子系统区分。
enum BarkLog {
    static let push = Logger(subsystem: "com.barkagent.ios", category: "push")
    static let lifecycle = Logger(subsystem: "com.barkagent.ios", category: "lifecycle")
    static let storage = Logger(subsystem: "com.barkagent.ios", category: "storage")
}

/// Debug-only print。Release 编译时整个表达式被剥离，不会出现在二进制里。
@inlinable
func dprint(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
