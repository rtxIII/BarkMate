//
//  ShareView.swift
//  ShareExtension
//
//  Phase 5-Core: Share Extension SwiftUI 表单。极简：标题（可选）+ 正文。
//

import SwiftUI

struct ShareDraft: Equatable {
    var title: String = ""
    var body: String = ""
    var url: String?
}

struct ShareView: View {

    @State private var draft: ShareDraft

    let onSave: (ShareDraft) -> Void
    let onCancel: () -> Void

    init(initial: ShareDraft, onSave: @escaping (ShareDraft) -> Void, onCancel: @escaping () -> Void) {
        self._draft = State(initialValue: initial)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Optional", text: $draft.title)
                        .autocorrectionDisabled()
                }

                Section("Note") {
                    TextEditor(text: $draft.body)
                        .frame(minHeight: 160)
                }

                if let url = draft.url, !url.isEmpty {
                    Section("Source") {
                        Text(url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .navigationTitle("Save to BarkMate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft) }
                        .disabled(draft.title.isEmpty && draft.body.isEmpty)
                }
            }
        }
    }
}
