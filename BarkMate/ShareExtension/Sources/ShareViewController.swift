//
//  ShareViewController.swift
//  ShareExtension
//
//  Phase 5-Core: SwiftUI hosted share extension.
//  从其它 App 接收 NSExtensionItem (text / url) → 创建 manual Memo → 入库
//  → 发 Darwin 通知主 App 刷新。失败走 PendingQueue 旁路。
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import Models
import Store
import BarkService

final class ShareViewController: UIViewController {

    private var hostingController: UIHostingController<ShareView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        Task { @MainActor in
            let extracted = await Self.extractDraft(from: extensionContext)
            mountSwiftUI(initial: extracted)
        }
    }

    // MARK: - SwiftUI mount

    @MainActor
    private func mountSwiftUI(initial: ShareDraft) {
        let shareView = ShareView(
            initial: initial,
            onSave: { [weak self] draft in self?.save(draft: draft) },
            onCancel: { [weak self] in self?.cancel() }
        )
        let host = UIHostingController(rootView: shareView)
        host.view.backgroundColor = .systemBackground
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }

    // MARK: - Extraction

    private static func extractDraft(from context: NSExtensionContext?) async -> ShareDraft {
        guard let items = context?.inputItems as? [NSExtensionItem] else {
            return ShareDraft()
        }
        var draft = ShareDraft()
        for item in items {
            if let attributed = item.attributedContentText?.string, draft.body.isEmpty {
                draft.body = attributed
            }
            for provider in item.attachments ?? [] {
                if let url = await loadURL(provider) {
                    draft.url = url.absoluteString
                    if draft.body.isEmpty { draft.body = url.absoluteString }
                } else if let text = await loadText(provider) {
                    if draft.body.isEmpty { draft.body = text }
                }
            }
        }
        return draft
    }

    private static func loadURL(_ provider: NSItemProvider) async -> URL? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) else { return nil }
        return await withCheckedContinuation { cont in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, _ in
                cont.resume(returning: value as? URL)
            }
        }
    }

    private static func loadText(_ provider: NSItemProvider) async -> String? {
        let candidates = [UTType.plainText.identifier, UTType.text.identifier]
        for identifier in candidates where provider.hasItemConformingToTypeIdentifier(identifier) {
            let value = await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
                provider.loadItem(forTypeIdentifier: identifier, options: nil) { value, _ in
                    cont.resume(returning: value as? String)
                }
            }
            if let value, !value.isEmpty { return value }
        }
        return nil
    }

    // MARK: - Persistence

    private func save(draft: ShareDraft) {
        let trimmedBody = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty || !trimmedTitle.isEmpty else {
            cancel()
            return
        }

        let parsed = ParsedPush(
            id: UUID().uuidString,
            title: trimmedTitle.isEmpty ? nil : trimmedTitle,
            body: trimmedBody,
            bodyType: .markdown,
            tags: PushParser.extractTags(from: trimmedBody),
            url: draft.url
        )

        do {
            let container = try SharedModelContainer.make()
            let archiver = PushArchiver(modelContainer: container)
            try archiver.archive(parsed, fallbackMemoSource: .manual)
        } catch {
            try? PendingQueue().enqueue(parsed)
        }

        DarwinNotification.post(.itemDidArrive)
        completeRequest()
    }

    private func cancel() {
        extensionContext?.cancelRequest(
            withError: NSError(
                domain: "BarkMateShare",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "User cancelled"]
            )
        )
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
