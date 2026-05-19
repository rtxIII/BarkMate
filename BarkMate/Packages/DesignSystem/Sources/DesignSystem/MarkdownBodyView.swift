//
//  MarkdownBodyView.swift
//  DesignSystem
//
//  统一 markdown 渲染入口。Phase 3B 之后所有 body 走这里。
//  - plainText: 纯文本（保留换行）
//  - markdown: GFM via MarkdownUI（标题/列表/代码块/表格）
//

import SwiftUI
import MarkdownUI
import Models

public struct MarkdownBodyView: View {

    private let rawBody: String
    private let bodyType: BodyType
    private let lineLimit: Int?

    public init(body: String, bodyType: BodyType, lineLimit: Int? = nil) {
        self.rawBody = body
        self.bodyType = bodyType
        self.lineLimit = lineLimit
    }

    public var body: some View {
        switch bodyType {
        case .plainText:
            Text(rawBody)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
        case .markdown:
            Markdown(rawBody)
                .markdownTheme(barkmateTheme)
                .lineLimit(lineLimit)
        }
    }

    @MainActor
    private var barkmateTheme: Theme {
        Theme.gitHub
            .text {
                ForegroundColor(.primary)
                BackgroundColor(.clear)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
            }
            .heading1 { config in
                config.label
                    .markdownTextStyle {
                        FontWeight(.bold)
                        FontSize(.em(1.5))
                    }
            }
            .heading2 { config in
                config.label
                    .markdownTextStyle {
                        FontWeight(.semibold)
                        FontSize(.em(1.25))
                    }
            }
    }
}
