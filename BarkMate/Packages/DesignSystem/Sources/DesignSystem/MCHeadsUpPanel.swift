//
//  MCHeadsUpPanel.swift
//  DesignSystem
//
//  Dashboard 顶部 heads-up 大面板:三栏 triage(needsYou / running / settled)
//  + 顶部 "— HEADS-UP / N AGENTS —" + LIVE 脉冲。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .heads-up        L515  padding 14,1pt rule,hull 底
//    .heads-up .head  L522  10pt uppercase tracking 0.18em inkSoft
//    .pulse           L538  lime + box-shadow + 2s ease-in-out 脉冲
//    .triage          L548  grid 1.2fr 1fr 1fr,gap 8
//
//  数据源沿用 AgentHeroCounts(Phase 3.1 已建)。
//

import SwiftUI

public struct MCHeadsUpPanel: View {
    private let counts: AgentHeroCounts

    public init(counts: AgentHeroCounts) {
        self.counts = counts
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("— HEADS-UP / \(activeLabel) AGENTS —")
                Spacer()
                MCLivePulse()
            }
            .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(MissionControl.Color.inkSoft)

            HStack(alignment: .top, spacing: 8) {
                MCTriageCell(count: needsYouCount, bucket: .needsYou, subtitle: needsYouSubtitle)
                MCTriageCell(count: runningCount, bucket: .running, subtitle: runningSubtitle)
                MCTriageCell(count: settledCount, bucket: .settled, subtitle: settledSubtitle)
            }
        }
        .padding(14)
        .background(MissionControl.Color.hull)
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
        )
    }

    private var needsYouCount: Int {
        counts.waiting + counts.blocked
    }

    private var runningCount: Int {
        counts.running + counts.stale
    }

    private var settledCount: Int {
        counts.done + counts.failed
    }

    private var activeLabel: String {
        let n = counts.active
        return n < 10 ? "0\(n)" : "\(n)"
    }

    /// "01 wait · 01 stuck"(只列非零项)。0 → "—"。
    private var needsYouSubtitle: String {
        var parts: [String] = []
        if counts.waiting > 0 { parts.append("\(formatted(counts.waiting)) wait") }
        if counts.blocked > 0 { parts.append("\(formatted(counts.blocked)) stuck") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    /// "03 running"(+ stale 数量,如有)。
    private var runningSubtitle: String {
        var parts: [String] = []
        if counts.running > 0 { parts.append("\(formatted(counts.running)) running") }
        if counts.stale > 0 { parts.append("\(formatted(counts.stale)) stale") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    /// "01 done · 01 fail"。
    private var settledSubtitle: String {
        var parts: [String] = []
        if counts.done > 0 { parts.append("\(formatted(counts.done)) done") }
        if counts.failed > 0 { parts.append("\(formatted(counts.failed)) fail") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func formatted(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }
}

/// LIVE 脉冲指示器(2s ease-in-out 透明度循环)。
private struct MCLivePulse: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(MissionControl.Color.lime)
                .frame(width: 6, height: 6)
                .shadow(color: MissionControl.Color.lime, radius: 4, x: 0, y: 0)
                .opacity(pulse ? 0.4 : 1)
            Text("LIVE")
                .foregroundStyle(MissionControl.Color.lime)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    MCHeadsUpPanel(counts: AgentHeroCounts(
        running: 3, waiting: 1, blocked: 1, failed: 0, stale: 0, done: 1, active: 5
    ))
    .padding(.horizontal, 16)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
    .mcScreenBackground()
}
