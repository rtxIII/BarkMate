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
    private let selectedBucket: Binding<MissionControl.Status.Bucket?>?

    /// - Parameter selectedBucket: 提供后三格变为页面过滤器(点选高亮、再点取消);
    ///   nil 时退化为纯展示,兼容旧调用点。
    public init(
        counts: AgentHeroCounts,
        selectedBucket: Binding<MissionControl.Status.Bucket?>? = nil
    ) {
        self.counts = counts
        self.selectedBucket = selectedBucket
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("— HEADS-UP / \(displayedTotalLabel) AGENTS —")
                Spacer()
                MCLivePulse()
            }
            .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .bold))
            .tracking(1.8)
            .foregroundStyle(MissionControl.Color.inkSoft)

            HStack(alignment: .top, spacing: 8) {
                triageCell(count: needsYouCount, bucket: .needsYou, subtitle: needsYouSubtitle)
                triageCell(count: runningCount, bucket: .running, subtitle: runningSubtitle)
                triageCell(count: settledCount, bucket: .settled, subtitle: settledSubtitle)
            }
        }
        .padding(14)
        .background(MissionControl.Color.hull)
        .overlay(
            Rectangle()
                .stroke(MissionControl.Color.rule, lineWidth: MissionControl.Border.hairline)
        )
    }

    /// 有 selectedBucket → 可点按过滤(toggle 取消);无 → 纯展示。
    @ViewBuilder
    private func triageCell(
        count: Int,
        bucket: MissionControl.Status.Bucket,
        subtitle: String
    ) -> some View {
        if let selectedBucket {
            MCTriageCell(
                count: count,
                bucket: bucket,
                subtitle: subtitle,
                isSelected: selectedBucket.wrappedValue == bucket,
                onTap: {
                    selectedBucket.wrappedValue = selectedBucket.wrappedValue == bucket ? nil : bucket
                }
            )
        } else {
            MCTriageCell(count: count, bucket: bucket, subtitle: subtitle)
        }
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

    private var displayedTotalLabel: String {
        let displayedTotal = needsYouCount + runningCount + settledCount
        return displayedTotal < 10 ? "0\(displayedTotal)" : "\(displayedTotal)"
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
