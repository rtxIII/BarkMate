//
//  MCCodeBlock.swift
//  DesignSystem
//
//  Setup 屏 curl 模板等代码块。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .code-blk        L791  padding 14/16,void 底,1pt rule,3pt amber 左边
//    .code-blk::before L802 右上 `$ shell` 角标 amber 底 + void 字
//    .code-blk .k     L815  cyan(关键字)
//    .code-blk .s     L816  lime(字符串)
//    .code-blk .c     L817  slate(注释)
//

import SwiftUI

public struct MCCodeBlock: View {
    private let code: String
    private let label: String

    public init(_ code: String, label: String = "$ shell") {
        self.code = code
        self.label = label
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(code)
                .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .regular))
                .lineSpacing(7)
                .foregroundStyle(MissionControl.Color.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .padding(.trailing, 60)
                .background(MissionControl.Color.void)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(MissionControl.Color.amber)
                        .frame(width: 3)
                }
                .overlay(
                    Rectangle()
                        .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
                )

            Text(label.uppercased())
                .font(MissionControl.Font.jetBrainsMono(size: 8, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(MissionControl.Color.void)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(MissionControl.Color.amber)
        }
    }
}

#Preview {
    MCCodeBlock("""
    curl -X POST "https://api.day.app/<key>" \\
      -d "group=backend-refactor" \\
      -d "task_id=auth-migration-0420" \\
      -d "agent_status=running" \\
      -d "progress=3/8" \\
      -d "title=Refactoring auth middleware"
    """)
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
