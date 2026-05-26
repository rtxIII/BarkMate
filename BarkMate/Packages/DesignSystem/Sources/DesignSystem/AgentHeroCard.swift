//
//  AgentHeroCard.swift
//  DesignSystem
//
//  Dashboard 顶部深色 hero 卡。Iowan 26pt 标题 + 右上 68pt active 计数 +
//  下方 3 个 MiniStat(failed / stale / done)。
//

import SwiftUI

public struct AgentHeroCounts: Equatable, Sendable {
    public let running: Int
    public let waiting: Int
    public let blocked: Int
    public let failed: Int
    public let stale: Int
    public let done: Int
    public let active: Int

    public init(running: Int, waiting: Int, blocked: Int, failed: Int, stale: Int, done: Int, active: Int) {
        self.running = running
        self.waiting = waiting
        self.blocked = blocked
        self.failed = failed
        self.stale = stale
        self.done = done
        self.active = active
    }
}

public struct AgentHeroCard: View {
    private let counts: AgentHeroCounts

    public init(counts: AgentHeroCounts) {
        self.counts = counts
    }

    public var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Live agent map")
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.58))
                    Text("\(counts.running) running · \(counts.waiting) waiting · \(counts.blocked) blocked")
                        .font(BarkTheme.Typography.heroSerif(size: 26))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(counts.active)")
                    .font(BarkTheme.Typography.heroSerif(size: 68))
                    .tracking(-5)
                    .foregroundStyle(.white)
            }

            HStack(spacing: 9) {
                MiniStat(value: counts.failed, label: "failed")
                MiniStat(value: counts.stale, label: "stale")
                MiniStat(value: counts.done, label: "done")
            }
        }
        .padding(18)
        .heroBackground(decorationColor: BarkTheme.Palette.warningYellow.opacity(0.34))
    }
}

private struct MiniStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.11), lineWidth: 1)
        )
    }
}

/// 通用深色 hero 背景:ink → inkDeep 渐变 + 右上模糊装饰圆 + 圆角 30 + 阴影。
public extension View {
    func heroBackground(decorationColor: Color) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: BarkTheme.Corner.hero, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [BarkTheme.Palette.ink, BarkTheme.Palette.inkDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(decorationColor)
                            .frame(width: 170, height: 170)
                            .blur(radius: 12)
                            .offset(x: 62, y: -76)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: BarkTheme.Corner.hero, style: .continuous))
            .shadow(color: BarkTheme.Palette.ink.opacity(0.18), radius: 24, x: 0, y: 14)
    }
}

#Preview {
    AgentHeroCard(counts: AgentHeroCounts(
        running: 2, waiting: 1, blocked: 1, failed: 1, stale: 1, done: 1, active: 5
    ))
    .padding()
    .background(MockScreenBackground())
}
