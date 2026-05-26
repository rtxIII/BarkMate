//
//  FieldExplainer.swift
//  DesignSystem
//
//  Setup tab 用的字段对照行:左侧 monospace blue name + 右侧 medium 说明文案。
//

import SwiftUI

public struct FieldExplainer: View {
    private let name: String
    private let value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(BarkTheme.Palette.accentBlue)
                .frame(width: 104, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(BarkTheme.Palette.ink.opacity(0.68))
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        FieldExplainer(name: "group", value: "agent_id")
        FieldExplainer(name: "task_id", value: "同一任务的聚合键")
        FieldExplainer(name: "agent_status", value: "running / waiting_input / blocked / done / failed")
        FieldExplainer(name: "progress", value: "3/7 或 45%")
    }
    .mockCardPadding()
    .padding()
    .background(MockScreenBackground())
}
