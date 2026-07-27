//
//  AgentActivityAttributes.swift
//  Models
//
//  线 C:Live Activity 的 ActivityAttributes 定义(design §9.1)。
//  主 app(起/更/闭)与 Widget bundle(渲染)共用。ActivityKit 的 ActivityAttributes
//  在 macOS 上标记 unavailable(canImport 仍为 true,故不能用 canImport 判断),
//  Models 同时构建 macOS(swift test)→ 用 os(iOS) 隔离,不影响跨平台其余类型。
//

#if os(iOS)
import ActivityKit
import Foundation

public struct AgentActivityAttributes: ActivityAttributes {
    /// 随每次推送更新的动态内容。
    /// 只保留 LA UI 实际渲染的字段(status/stepTitle/progress)——全为字符串/枚举,
    /// 使远程 ActivityKit push 的 content-state wire 格式无 Date 歧义,server 可确定产出。
    public struct ContentState: Codable, Hashable, Sendable {
        public var status: AgentStatus
        public var stepTitle: String
        public var progress: String?

        public init(
            status: AgentStatus,
            stepTitle: String,
            progress: String? = nil
        ) {
            self.status = status
            self.stepTitle = stepTitle
            self.progress = progress
        }
    }

    /// LA 生命周期内不变的标识。
    public var agentID: String
    public var displayName: String
    public var iconURL: String?

    public init(agentID: String, displayName: String, iconURL: String? = nil) {
        self.agentID = agentID
        self.displayName = displayName
        self.iconURL = iconURL
    }
}
#endif
