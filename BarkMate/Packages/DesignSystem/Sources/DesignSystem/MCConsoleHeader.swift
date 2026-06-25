//
//  MCConsoleHeader.swift
//  DesignSystem
//
//  Mission Control 顶部 App bar。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .console-hd          L414  外层 padding 6/18/0
//    .console-hd .crumbs  L417  10pt caption mono uppercase
//    .console-hd .row     L430  flex space-between, align flex-end, padding-bottom 12, rule 底线
//    .console-hd h3       L437  30pt Inter Tight Black,letter-spacing -0.04em
//    .console-hd .serif   L446  Instrument Serif italic + amber
//
//  Crumbs 三段约定:
//    - middle 段(activeIndex,默认 1) → amber
//    - 其余段 → inkSoft
//    - 段间分隔 "/" → ruleHot
//

import SwiftUI

public struct MCConsoleHeader<Trailing: View>: View {
    private let crumbs: [String]
    private let activeCrumbIndex: Int
    private let title: String
    private let italicAccent: String?
    private let trailing: Trailing

    public init(
        crumbs: [String],
        activeCrumbIndex: Int = 1,
        title: String,
        italicAccent: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.crumbs = crumbs
        self.activeCrumbIndex = activeCrumbIndex
        self.title = title
        self.italicAccent = italicAccent
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            crumbsRow

            HStack(alignment: .bottom) {
                titleText
                Spacer(minLength: 8)
                trailing
            }
            .padding(.bottom, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(MissionControl.Color.rule)
                    .frame(height: MissionControl.Border.hairline)
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 18)
    }

    // MARK: - Crumbs

    private var crumbsRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(crumbs.enumerated()), id: \.offset) { index, segment in
                Text(segment.uppercased())
                    .foregroundStyle(crumbColor(forIndex: index))
                if index < crumbs.count - 1 {
                    Text("/")
                        .foregroundStyle(MissionControl.Color.ruleHot)
                }
            }
        }
        .font(MissionControl.Font.captionMono)
        .tracking(1.4)
    }

    private func crumbColor(forIndex index: Int) -> Color {
        index == activeCrumbIndex
            ? MissionControl.Color.amber
            : MissionControl.Color.inkSoft
    }

    // MARK: - Title

    private var titleText: Text {
        var combined = Text(title)
            .font(MissionControl.Font.titleXL)
            .foregroundColor(MissionControl.Color.ink)
            .tracking(-1.2)

        if let italicAccent, !italicAccent.isEmpty {
            combined = combined + Text(italicAccent)
                .font(MissionControl.Font.italicAccent(size: 30))
                .foregroundColor(MissionControl.Color.amber)
        }
        return combined
    }
}

#Preview {
    VStack(spacing: 24) {
        MCConsoleHeader(
            crumbs: ["OPS", "TODAY", "MON · 0615"],
            title: "",
            italicAccent: "Today."
        ) {
            Text("⌁")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MissionControl.Color.ink)
                .frame(width: 32, height: 32)
                .overlay(Rectangle().stroke(MissionControl.Color.ruleHot, lineWidth: 1))
        }

        MCConsoleHeader(
            crumbs: ["SYS", "SETUP", "0001"],
            title: "First ",
            italicAccent: "push"
        )

        MCConsoleHeader(
            crumbs: ["OPS", "DOSSIER", "TASK-0420"],
            title: "Dossier"
        )
    }
    .mcScreenBackground()
}
