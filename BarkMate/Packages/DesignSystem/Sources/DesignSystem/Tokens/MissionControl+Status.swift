//
//  MissionControl+Status.swift
//  DesignSystem
//
//  Mission Control 状态码渲染映射。
//
//  把 AgentStatus 映射为:
//   - `[ WAIT ]` 等方括号大写状态码字符串
//   - 对应的 HUD 颜色(amber / cyan / lime / orange / magenta / slate)
//   - 对应的辉光颜色(用于 glow shadow / box-shadow)
//
//  设计原则:
//   - 不修改 `BarkTheme` 里的 `AgentStatus.color`(它仍指向旧的暖纸蓝)
//   - 新增 `mcCode` / `mcColor` / `mcGlow` 三个独立扩展属性,供 Mission Control 组件使用
//   - 旧组件不受影响,新组件显式选择 mc* 前缀的属性
//

import SwiftUI
import Models

extension MissionControl {

    /// AgentStatus → 渲染上下文。组件层调用 `MissionControl.Status.render(for:)`
    /// 一次性拿到 code / color / glow,避免多处分散查表。
    public enum Status {

        /// 状态渲染束。
        public struct Render: Sendable, Hashable {
            /// 大写方括号码,如 `[ WAIT ]`、`[ STUCK ]`。
            public let code: String
            /// 主色调(HUD 5 色之一,或 slate)。
            public let color: SwiftUI.Color
            /// 辉光色(主色 alpha 14%),用于 glow shadow / 进度条阴影。
            public let glow: SwiftUI.Color
            /// 是否属于 "Needs you"(需要用户介入的紧急状态)。
            public let needsAttention: Bool
        }

        /// 主查询入口。
        public static func render(for status: AgentStatus) -> Render {
            switch status {
            case .waitingInput:
                return Render(
                    code: "[ WAIT ]",
                    color: MissionControl.Color.amber,
                    glow: MissionControl.Color.amberGlow,
                    needsAttention: true
                )
            case .blocked:
                return Render(
                    code: "[ STUCK ]",
                    color: MissionControl.Color.orange,
                    glow: MissionControl.Color.orangeGlow,
                    needsAttention: true
                )
            case .running:
                return Render(
                    code: "[ RUN ]",
                    color: MissionControl.Color.cyan,
                    glow: MissionControl.Color.cyanGlow,
                    needsAttention: false
                )
            case .done:
                return Render(
                    code: "[ DONE ]",
                    color: MissionControl.Color.lime,
                    glow: MissionControl.Color.limeGlow,
                    needsAttention: false
                )
            case .failed:
                return Render(
                    code: "[ FAIL ]",
                    color: MissionControl.Color.magenta,
                    glow: MissionControl.Color.magentaGlow,
                    needsAttention: true
                )
            case .stale:
                return Render(
                    code: "[ STALE ]",
                    color: MissionControl.Color.inkMute,
                    glow: MissionControl.Color.ruleHot,
                    needsAttention: false
                )
            }
        }

        /// Dashboard triage 三栏分桶。
        public enum Bucket: String, CaseIterable, Sendable {
            /// waiting_input + blocked + failed(需要用户介入)。
            case needsYou
            /// running + stale(系统自己在跑,无需介入)。
            case running
            /// done(已结束,可归档)。
            case settled
        }

        /// 把 AgentStatus 归入三个 triage 桶之一。
        /// mock B 把 .failed 归入 Settled 段（已结束的终态，只需"看一眼"而非 needs you 那种交互）。
        public static func bucket(for status: AgentStatus) -> Bucket {
            switch status {
            case .waitingInput, .blocked:
                return .needsYou
            case .running, .stale:
                return .running
            case .done, .failed:
                return .settled
            }
        }

        /// triage 桶的展示标题(Mock B Dashboard 三栏)。
        public static func bucketTitle(_ bucket: Bucket) -> String {
            switch bucket {
            case .needsYou: return "Needs you"
            case .running: return "Running"
            case .settled: return "Settled"
            }
        }

        /// triage 桶的代表色(用于数字着色)。
        public static func bucketColor(_ bucket: Bucket) -> SwiftUI.Color {
            switch bucket {
            case .needsYou: return MissionControl.Color.amber
            case .running: return MissionControl.Color.cyan
            case .settled: return MissionControl.Color.inkMute
            }
        }
    }
}

// MARK: - AgentStatus convenience accessors

extension AgentStatus {
    /// Mission Control 状态码字符串,如 `[ WAIT ]`。
    public var mcCode: String {
        MissionControl.Status.render(for: self).code
    }

    /// Mission Control HUD 色。
    public var mcColor: Color {
        MissionControl.Status.render(for: self).color
    }

    /// Mission Control 辉光色(主色 14% alpha)。
    public var mcGlow: Color {
        MissionControl.Status.render(for: self).glow
    }

    /// 是否需要用户介入(归入 "Needs you" 桶)。
    public var mcNeedsAttention: Bool {
        MissionControl.Status.render(for: self).needsAttention
    }

    /// triage 桶。
    public var mcBucket: MissionControl.Status.Bucket {
        MissionControl.Status.bucket(for: self)
    }
}
