//
//  MCScreenBackground.swift
//  DesignSystem
//
//  Mission Control 屏幕背景。深底 void + 32px 栅格 mask + 横扫描线。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    body::before  — 32px 栅格,radial mask
//    body::after   — 2px 横向扫描线
//    .screen::after — 每屏内的弱扫描线
//
//  使用方法:
//    SomeView()
//        .mcScreenBackground()
//

import SwiftUI

public struct MCScreenBackground: View {

    public init() {}

    public var body: some View {
        ZStack {
            // 1. void 底层 + 两道径向辉光(琥珀/青)模拟 mock body 的 radial-gradient
            MissionControl.Color.background

            LinearGradient(
                colors: [MissionControl.Color.void, MissionControl.Color.hull.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            // 琥珀辉光在左上
            RadialGradient(
                gradient: Gradient(colors: [
                    MissionControl.Color.amber.opacity(0.08),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.12, y: 0.06),
                startRadius: 0,
                endRadius: 320
            )

            // 青辉光在右下
            RadialGradient(
                gradient: Gradient(colors: [
                    MissionControl.Color.cyan.opacity(0.07),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.88, y: 0.92),
                startRadius: 0,
                endRadius: 320
            )

            // 2. 32pt 栅格(线宽 1pt, 半透明 ink)整屏渲染。
            //    mock B 的栅格效果是「整屏均匀微弱可见」,因此不用 radial mask。
            MCGridOverlay()

            // 3. 横向扫描线
            MCScanlineOverlay()
        }
        .ignoresSafeArea()
    }
}

/// 32pt 间距的栅格线。线宽 1pt,半透明 ink。
private struct MCGridOverlay: View {
    private let spacing: CGFloat = 32

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let lineColor = MissionControl.Color.ink.opacity(0.025)
                let path = Path { p in
                    // 垂直线
                    var x: CGFloat = 0
                    while x < size.width {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }
                    // 水平线
                    var y: CGFloat = 0
                    while y < size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }
                }
                ctx.stroke(path, with: .color(lineColor), lineWidth: 1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
    }
}

/// 每 3pt 一道的横向扫描线。透明度 ~1.2%,几乎不可见但赋予战术 CRT 质感。
private struct MCScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let lineColor = MissionControl.Color.ink.opacity(0.012)
                let path = Path { p in
                    var y: CGFloat = 0
                    while y < size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        y += 3
                    }
                }
                ctx.stroke(path, with: .color(lineColor), lineWidth: 1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - View Modifier API

extension View {
    /// 给屏幕容器套上 Mission Control 背景(void + 栅格 + 扫描线)。
    /// 背景层强制 allowsHitTesting(false),防止 ZStack / Canvas 吃掉 hit test。
    public func mcScreenBackground() -> some View {
        self.background(
            MCScreenBackground()
                .allowsHitTesting(false)
        )
    }
}

#Preview {
    ZStack {
        MCScreenBackground()
        VStack(spacing: 16) {
            Text("Mission Control")
                .font(MissionControl.Font.titleXL)
                .foregroundStyle(MissionControl.Color.foreground)
            Text("void · grid · scanlines")
                .font(MissionControl.Font.captionMono)
                .foregroundStyle(MissionControl.Color.foregroundSoft)
        }
    }
}
