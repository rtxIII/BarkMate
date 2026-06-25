//
//  AgentShareSnippet.swift
//  DesignSystem
//
//  把 AgentCardData / DetailHeroData 序列化为可分享给他人的多行文本片段。
//
//  Mission Control 风格,与 mock B 的卡片信息密度一致:
//      test-writer · [ WAIT ]
//      task: TASK-0420 · 04/07
//      "Confirm overwrite existing mocks"
//      updated 2m ago
//
//  v1 只输出文本;v1.1 可考虑用 ImageRenderer 渲染卡片截图共享。
//

import Foundation
import Models

public enum AgentShareSnippet {

    /// 由 AgentCardData 构造一段四行人类可读的状态片段。
    public static func text(from data: AgentCardData) -> String {
        var lines: [String] = []

        lines.append("\(data.agentName) · \(data.status.mcCode)")

        let metadata = makeMetadata(taskID: data.taskID, progress: data.progressLabel)
        if !metadata.isEmpty { lines.append(metadata) }

        if !data.latestStep.isEmpty {
            lines.append("\u{201C}\(data.latestStep)\u{201D}")
        }

        if !data.updatedLabel.isEmpty {
            lines.append(data.updatedLabel)
        }

        return lines.joined(separator: "\n")
    }

    /// 由 DetailHeroData 构造分享片段(detail 页用)。
    /// 与 AgentCardData 等价但字段映射不同。
    public static func text(from data: DetailHeroData) -> String {
        var lines: [String] = []

        lines.append("\(data.agentName) · \(data.status.mcCode)")

        let metadata = makeMetadata(taskID: data.taskID, progress: data.progressLabel)
        if !metadata.isEmpty { lines.append(metadata) }

        if !data.etaLabel.isEmpty && data.etaLabel != "—" {
            lines.append("eta \(data.etaLabel)")
        }
        if !data.updatedLabel.isEmpty {
            lines.append(data.updatedLabel)
        }

        return lines.joined(separator: "\n")
    }

    private static func makeMetadata(taskID: String?, progress: String?) -> String {
        var pieces: [String] = []
        if let taskID, !taskID.isEmpty { pieces.append("task: \(taskID)") }
        if let progress, !progress.isEmpty, progress != "—" { pieces.append(progress) }
        return pieces.joined(separator: " · ")
    }
}
