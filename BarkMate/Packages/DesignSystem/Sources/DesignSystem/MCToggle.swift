//
//  MCToggle.swift
//  DesignSystem
//
//  Mission Control 锐角开关。**不**使用系统 Toggle(圆胶囊与 MC 风冲突)。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .toggle         L1303  44×22,1pt ruleHot,hull 底
//    .toggle::before L1311  16×16 knob,top 2 left 2,inkSoft
//    .toggle.on      L1321  amber 底 + amber 边
//    .toggle.on::before L1322  knob 平移 22,改 void
//

import SwiftUI

public struct MCToggle: View {
    @Binding private var isOn: Bool
    private let label: String?

    public init(isOn: Binding<Bool>, label: String? = nil) {
        self._isOn = isOn
        self.label = label
    }

    public var body: some View {
        Button {
            isOn.toggle()
        } label: {
            switchTrack
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(label ?? "", isOn: $isOn)
        }
    }

    private var switchTrack: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(isOn ? MissionControl.Color.amber : MissionControl.Color.hull)
                .frame(width: 44, height: 22)
                .overlay(
                    Rectangle()
                        .stroke(
                            isOn ? MissionControl.Color.amber : MissionControl.Color.ruleHot,
                            lineWidth: MissionControl.Border.hairline
                        )
                )

            Rectangle()
                .fill(isOn ? MissionControl.Color.void : MissionControl.Color.inkSoft)
                .frame(width: 16, height: 16)
                .offset(x: isOn ? 24 : 2)
        }
        .frame(width: 44, height: 22)
        .animation(.easeOut(duration: 0.25), value: isOn)
        .contentShape(Rectangle())
    }
}

#Preview {
    struct Preview: View {
        @State private var a = false
        @State private var b = true

        var body: some View {
            VStack(spacing: 14) {
                MCToggle(isOn: $a, label: "Live Activity")
                MCToggle(isOn: $b, label: "Allow critical")
            }
            .padding()
            .background(MissionControl.Color.void)
        }
    }
    return Preview()
}
