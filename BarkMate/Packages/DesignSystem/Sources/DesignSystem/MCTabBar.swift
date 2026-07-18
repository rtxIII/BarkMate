//
//  MCTabBar.swift
//  DesignSystem
//
//  Mission Control 自绘分段 tab bar。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .tabbar        L478  grid 4 cols,1pt rule,hull 背景
//    .tabbar div    L488  padding 12/4/10,9pt uppercase tracking 0.12em,inkSoft
//    .tabbar div b  L501  mono 14pt 上行图标
//    .tabbar .active L508 amber 背景,void 文字
//
//  注意:本组件**不替换** SwiftUI 系统 TabView,仅作为独立分段控件,
//  供后续 P1–P5 屏在需要 Mission Control 风格 segmented control 时按需嵌入。
//

import SwiftUI

public struct MCTabBarItem<Tab: Hashable>: Identifiable {
    public let id: Tab
    public let glyph: String
    public let label: String

    public init(id: Tab, glyph: String, label: String) {
        self.id = id
        self.glyph = glyph
        self.label = label
    }
}

public struct MCTabBar<Tab: Hashable>: View {
    private let items: [MCTabBarItem<Tab>]
    @Binding private var selection: Tab
    private let extraBottomPadding: CGFloat

    public init(
        items: [MCTabBarItem<Tab>],
        selection: Binding<Tab>,
        extraBottomPadding: CGFloat = 0
    ) {
        self.items = items
        self._selection = selection
        self.extraBottomPadding = extraBottomPadding
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                cell(for: item)
                if index < items.count - 1 {
                    Rectangle()
                        .fill(MissionControl.Color.rule)
                        .frame(width: MissionControl.Border.hairline)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(MissionControl.Color.hull)
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
        )
    }

    private func cell(for item: MCTabBarItem<Tab>) -> some View {
        let isActive = item.id == selection
        return Button {
            selection = item.id
        } label: {
            VStack(spacing: 3) {
                Text(item.glyph)
                    .font(MissionControl.Font.jetBrainsMono(size: 13, weight: .bold))
                Text(item.label.uppercased())
                    .font(MissionControl.Font.jetBrainsMono(size: 8.5, weight: .bold))
                    .tracking(1.1)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8 + extraBottomPadding)
            .padding(.horizontal, 4)
            .foregroundStyle(isActive ? MissionControl.Color.void : MissionControl.Color.inkSoft)
            .background(isActive ? MissionControl.Color.amber : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.label))
        .accessibilityIdentifier("tab-\(item.label.lowercased())")
    }
}

#Preview {
    struct Preview: View {
        @State private var tab = "agents"

        var body: some View {
            VStack {
                Spacer()
                MCTabBar(
                    items: [
                        MCTabBarItem(id: "agents", glyph: "▦", label: "Agents"),
                        MCTabBarItem(id: "history", glyph: "≡", label: "History"),
                        MCTabBarItem(id: "search", glyph: "⌕", label: "Search"),
                        MCTabBarItem(id: "settings", glyph: "⚙", label: "Settings")
                    ],
                    selection: $tab
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
            .mcScreenBackground()
        }
    }
    return Preview()
}
