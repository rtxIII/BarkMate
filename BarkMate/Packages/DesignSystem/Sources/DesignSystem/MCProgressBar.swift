//
//  MCProgressBar.swift
//  DesignSystem
//
//  Mission Control 4pt 高纯矩形进度条。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .r-row .bar    L729  height 4pt,background rule
//    .r-row .bar i  L734  填充层,background cyan,box-shadow 0 0 6px cyan-glow
//    .r-row.done    L750  done 态填充改 lime
//
//  替代 SwiftUI 原生 ProgressView()(后者圆角胶囊与 Mission Control 锐角风冲突)。
//

import SwiftUI
import Models

public struct MCProgressBar: View {
    private let value: Double
    private let color: Color
    private let glow: Color

    /// 主入口:caller 自定义颜色 / glow。value clamp 到 [0, 1]。
    public init(value: Double, color: Color, glow: Color) {
        self.value = max(0, min(1, value))
        self.color = color
        self.glow = glow
    }

    /// 便利入口:由 AgentStatus 推导 color / glow。
    public init(status: AgentStatus, value: Double) {
        let render = MissionControl.Status.render(for: status)
        self.init(value: value, color: render.color, glow: render.glow)
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                MissionControl.Color.rule
                Rectangle()
                    .fill(color)
                    .frame(width: geo.size.width * value)
                    .shadow(
                        color: glow,
                        radius: 6,
                        x: 0,
                        y: 0
                    )
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("progress")
        .accessibilityValue(Text("\(Int(value * 100)) percent"))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        MCProgressBar(status: .running, value: 0.42)
        MCProgressBar(status: .done, value: 1.0)
        MCProgressBar(status: .waitingInput, value: 0.18)
        MCProgressBar(status: .failed, value: 0.66)
        MCProgressBar(value: 0.5, color: MissionControl.Color.lime, glow: MissionControl.Color.limeGlow)
    }
    .padding()
    .background(MissionControl.Color.void)
}
