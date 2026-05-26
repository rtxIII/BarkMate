//
//  NotificationStatusBanner.swift
//  DesignSystem
//
//  Setup tab 顶部的健康状态条。仅在非 .ok / 非 .unknown 时显示。
//  视觉:左侧 SF Symbol + 标题 / 副标题;右侧操作 chip。配色:
//    - authorizationDenied -> warningYellow
//    - apnsRegistrationFailed -> alertOrange
//    - serverUnreachable -> errorRed
//

import SwiftUI

public struct NotificationStatusBannerData: Equatable, Sendable {
    public enum Kind: Sendable, Equatable {
        case authorizationDenied
        case apnsRegistrationFailed
        case serverUnreachable
    }

    public let kind: Kind
    public let detail: String?
    public let actionLabel: String

    public init(kind: Kind, detail: String?, actionLabel: String) {
        self.kind = kind
        self.detail = detail
        self.actionLabel = actionLabel
    }
}

public struct NotificationStatusBanner: View {
    private let data: NotificationStatusBannerData
    private let onAction: () -> Void

    public init(data: NotificationStatusBannerData, onAction: @escaping () -> Void) {
        self.data = data
        self.onAction = onAction
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                if let detail = data.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)

            Button(data.actionLabel, action: onAction)
                .font(.caption.weight(.heavy))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.20), in: Capsule())
                .foregroundStyle(.white)
        }
        .padding(13)
        .background(accent, in: RoundedRectangle(cornerRadius: BarkTheme.Corner.mockCard, style: .continuous))
        .shadow(color: accent.opacity(0.34), radius: 14, x: 0, y: 6)
    }

    private var iconName: String {
        switch data.kind {
        case .authorizationDenied: return "bell.slash.fill"
        case .apnsRegistrationFailed: return "antenna.radiowaves.left.and.right.slash"
        case .serverUnreachable: return "exclamationmark.icloud.fill"
        }
    }

    private var title: String {
        switch data.kind {
        case .authorizationDenied: return "Notifications disabled"
        case .apnsRegistrationFailed: return "APNs registration failed"
        case .serverUnreachable: return "Server unreachable"
        }
    }

    private var accent: Color {
        switch data.kind {
        case .authorizationDenied: return BarkTheme.Palette.warningYellow
        case .apnsRegistrationFailed: return BarkTheme.Palette.alertOrange
        case .serverUnreachable: return BarkTheme.Palette.errorRed
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        NotificationStatusBanner(
            data: .init(
                kind: .authorizationDenied,
                detail: "Notifications were denied. Open Settings → BarkMate.",
                actionLabel: "Open"
            ),
            onAction: {}
        )
        NotificationStatusBanner(
            data: .init(
                kind: .apnsRegistrationFailed,
                detail: "APNs error: NSURLErrorTimedOut",
                actionLabel: "Retry"
            ),
            onAction: {}
        )
        NotificationStatusBanner(
            data: .init(
                kind: .serverUnreachable,
                detail: "BarkMate Cloud failed to register. Open Servers to retry.",
                actionLabel: "Servers"
            ),
            onAction: {}
        )
    }
    .padding()
    .background(MockScreenBackground())
}
