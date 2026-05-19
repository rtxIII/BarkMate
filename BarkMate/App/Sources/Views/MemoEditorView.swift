//
//  MemoEditorView.swift
//  BarkMate
//
//  Phase 3B: 全屏备忘录编辑器。Markdown body + 草稿自动保存。
//  Phase 3C: PhotosPicker 附件（保存为 Resource 链接到 Item）。
//

import SwiftUI
import SwiftData
import PhotosUI
import Models
import Store
import DesignSystem
import MarkdownUI

struct MemoEditorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var titleText: String = ""
    @State private var bodyText: String = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var attachments: [PendingAttachment] = []
    @State private var showPreview: Bool = false

    private let draftManager: DraftManager

    init(draftManager: DraftManager = DraftManager()) {
        self.draftManager = draftManager
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("New Memo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .onAppear(perform: loadDraft)
                .onChange(of: titleText) { _, _ in persistDraft() }
                .onChange(of: bodyText) { _, _ in persistDraft() }
                .onChange(of: pickerItems) { _, newItems in
                    Task { await processPicked(newItems) }
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BarkTheme.Spacing.md) {
                TextField("Title (optional)", text: $titleText)
                    .font(.title3.bold())
                    .textFieldStyle(.plain)

                Divider()

                if showPreview {
                    previewPane
                } else {
                    editorPane
                }

                if !attachments.isEmpty {
                    AttachmentStrip(attachments: attachments) { removeAttachment($0) }
                }
            }
            .padding(BarkTheme.Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) { attachmentToolbar }
    }

    private var editorPane: some View {
        TextEditor(text: $bodyText)
            .font(.body)
            .frame(minHeight: 240)
            .overlay(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text("Write markdown here — try **bold**, lists, `code`.")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                        .padding(.top, 6)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private var previewPane: some View {
        if bodyText.isEmpty {
            Text("Nothing to preview yet.")
                .foregroundStyle(.secondary)
                .frame(minHeight: 240, alignment: .topLeading)
        } else {
            Markdown(bodyText)
                .frame(minHeight: 240, alignment: .topLeading)
        }
    }

    private var attachmentToolbar: some View {
        HStack {
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                Label("Attach", systemImage: "photo.badge.plus")
                    .font(.callout)
            }
            Spacer()
            Text("\(bodyText.count) chars")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, BarkTheme.Spacing.lg)
        .padding(.vertical, BarkTheme.Spacing.sm)
        .background(.bar)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Save", action: save).disabled(bodyText.isEmpty && titleText.isEmpty)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Toggle(isOn: $showPreview) {
                Image(systemName: showPreview ? "pencil" : "eye")
            }
            .toggleStyle(.button)
        }
    }

    // MARK: - Draft

    private func loadDraft() {
        guard titleText.isEmpty, bodyText.isEmpty, let draft = draftManager.load() else { return }
        titleText = draft.title ?? ""
        bodyText = draft.body
    }

    private func persistDraft() {
        if titleText.isEmpty && bodyText.isEmpty {
            draftManager.clear()
            return
        }
        draftManager.save(.init(body: bodyText, title: titleText.isEmpty ? nil : titleText))
    }

    // MARK: - Attachments (Batch 3C)

    private func processPicked(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let saved = saveAttachment(data: data) {
                attachments.append(saved)
            }
        }
        pickerItems.removeAll()
    }

    private func saveAttachment(data: Data) -> PendingAttachment? {
        do {
            try AppGroup.ensureDirectories()
            let filename = "\(UUID().uuidString).jpg"
            let url = AppGroup.resourcesDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            return PendingAttachment(
                filename: filename,
                localPath: "resources/\(filename)",
                size: Int64(data.count)
            )
        } catch {
            print("[MemoEditor] save attachment failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func removeAttachment(_ attachment: PendingAttachment) {
        attachments.removeAll { $0.id == attachment.id }
        let url = AppGroup.containerURL.appendingPathComponent(attachment.localPath)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Save

    private func save() {
        let trimmedBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty || !trimmedTitle.isEmpty else { return }

        let memo = ItemFactory.memo(title: trimmedTitle, body: trimmedBody)
        modelContext.insert(memo)
        memo.resources = attachments.map { pending in
            Resource(
                filename: pending.filename,
                mimeType: "image/jpeg",
                localPath: pending.localPath,
                size: pending.size
            )
        }
        try? modelContext.save()
        draftManager.clear()
        dismiss()
    }
}

// MARK: - Helpers

private struct PendingAttachment: Identifiable, Equatable {
    let id: UUID = UUID()
    let filename: String
    let localPath: String
    let size: Int64
}

private struct AttachmentStrip: View {
    let attachments: [PendingAttachment]
    let onRemove: (PendingAttachment) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BarkTheme.Spacing.sm) {
                ForEach(attachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        AttachmentThumb(attachment: attachment)
                        Button {
                            onRemove(attachment)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
        }
    }
}

private struct AttachmentThumb: View {
    let attachment: PendingAttachment
    var body: some View {
        let url = AppGroup.containerURL.appendingPathComponent(attachment.localPath)
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty: Color.gray.opacity(0.2)
            case .success(let image): image.resizable().scaledToFill()
            case .failure: Color.red.opacity(0.2)
            @unknown default: Color.gray.opacity(0.2)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: BarkTheme.Corner.chip))
    }
}

private enum ItemFactory {
    static func memo(title: String, body: String) -> Item {
        let tags = extractTags(from: body)
        return Item(
            type: .memo,
            title: title.isEmpty ? nil : title,
            body: body,
            bodyType: .markdown,
            tags: tags
        )
    }

    private static func extractTags(from body: String) -> [String] {
        // 与 PushParser.extractTags 同规则的轻量实现
        var result: [String] = []
        var seen: Set<String> = []
        let scanner = Scanner(string: body)
        scanner.charactersToBeSkipped = nil
        let tagChars = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "_-"))
            .union(CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}"))

        while !scanner.isAtEnd {
            _ = scanner.scanUpToString("#")
            guard scanner.scanString("#") != nil else { break }
            guard let tag = scanner.scanCharacters(from: tagChars), !tag.isEmpty else { continue }
            if !seen.contains(tag) {
                seen.insert(tag)
                result.append(tag)
            }
        }
        return result
    }
}
