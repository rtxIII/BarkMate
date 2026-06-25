//
//  MCResultRow.swift
//  DesignSystem
//
//  Mission Control 搜索结果行。
//
//  视觉契约参考:doc/mock/screens-b-missioncontrol.html
//    .s-res             L1189  grid 56pt + 1fr + auto,gap 12,padding 11/0
//    .s-res             L1194  底部 1pt rule
//    .s-res .kind       L1200  9pt 700 uppercase tracking 0.14em
//    .s-res .kind.a     L1206  magenta (agent)
//    .s-res .kind.s     L1207  cyan (step)
//    .s-res .kind.m     L1208  lime (memo)
//    .s-res .body strong L1209 Inter Tight 13.5pt 700 ink -0.02em
//    .s-res .body p     L1217  11pt inkSoft line-height 1.45
//    .s-res .body em.hit L1223 amber 底 + void 字
//    .s-res time        L1230  10pt inkSoft 0.04em
//
//  caller 提供 query 字符串,本组件构造 AttributedString 做大小写不敏感高亮。
//

import SwiftUI

public struct MCResultRow: View {

    /// 结果种类(用于决定 3 字母 prefix 与配色)。
    public enum Kind {
        case agent  // AGT · magenta
        case step   // STP · cyan
        case memo   // MEM · lime
        case incoming // INC · lime (与 memo 同色,旧 Bark 推送归类)

        var label: String {
            switch self {
            case .agent: return "AGT"
            case .step: return "STP"
            case .memo: return "MEM"
            case .incoming: return "INC"
            }
        }

        var color: Color {
            switch self {
            case .agent: return MissionControl.Color.magenta
            case .step: return MissionControl.Color.cyan
            case .memo, .incoming: return MissionControl.Color.lime
            }
        }
    }

    private let kind: Kind
    private let title: String
    private let bodyText: String
    private let query: String
    private let timeLabel: String

    public init(kind: Kind, title: String, body: String, query: String, timeLabel: String) {
        self.kind = kind
        self.title = title
        self.bodyText = body
        self.query = query
        self.timeLabel = timeLabel
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(kind.label)
                .font(MissionControl.Font.jetBrainsMono(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(kind.color)
                .frame(width: 56, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(Self.highlight(title, query: query, isBody: false))
                    .lineLimit(1)
                Text(Self.highlight(bodyText, query: query, isBody: true))
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(timeLabel)
                .font(MissionControl.Font.jetBrainsMono(size: 10, weight: .regular))
                .tracking(0.4)
                .foregroundStyle(MissionControl.Color.inkSoft)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MissionControl.Color.rule)
                .frame(height: MissionControl.Border.hairline)
        }
    }

    /// 把 text 中匹配 query(大小写不敏感)的子串渲染成 amber 高亮。
    private static func highlight(_ text: String, query: String, isBody: Bool) -> AttributedString {
        let baseFont: SwiftUI.Font = isBody
            ? MissionControl.Font.jetBrainsMono(size: 11, weight: .regular)
            : MissionControl.Font.interTight(size: 13.5, weight: .bold)
        let baseColor: Color = isBody
            ? MissionControl.Color.inkSoft
            : MissionControl.Color.ink

        var attr = AttributedString(text)
        attr.font = baseFont
        attr.foregroundColor = baseColor
        if !isBody {
            attr.tracking = -0.27
        }

        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return attr }

        let lower = text.lowercased() as NSString
        let target = trimmed.lowercased() as NSString
        var searchRange = NSRange(location: 0, length: lower.length)

        while searchRange.location < lower.length {
            let foundRange = lower.range(
                of: target as String,
                options: .literal,
                range: searchRange
            )
            if foundRange.location == NSNotFound { break }
            if let stringRange = Range(foundRange, in: text),
               let attrRange = attr.range(of: String(text[stringRange])) {
                attr[attrRange].backgroundColor = MissionControl.Color.amber
                attr[attrRange].foregroundColor = MissionControl.Color.void
            }
            let nextLocation = foundRange.location + foundRange.length
            searchRange = NSRange(location: nextLocation, length: lower.length - nextLocation)
        }
        return attr
    }
}

#Preview {
    VStack(spacing: 0) {
        MCResultRow(
            kind: .agent,
            title: "backend-refactor",
            body: "Refactoring auth middleware. mock-coverage in progress.",
            query: "mock",
            timeLabel: "10:42"
        )
        MCResultRow(
            kind: .step,
            title: "Updated auth.ts",
            body: "Extracted token validation into a smaller middleware function.",
            query: "auth",
            timeLabel: "10:25"
        )
        MCResultRow(
            kind: .memo,
            title: "Deploy preview link",
            body: "Saved from Share Extension placeholder. mock-coverage feedback.",
            query: "mock",
            timeLabel: "JUN 12"
        )
    }
    .padding(.horizontal, 16)
    .mcScreenBackground()
}
