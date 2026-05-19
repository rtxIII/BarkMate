//
//  PushArchiver.swift
//  BarkService
//
//  ParsedPush → SwiftData Item 入库。
//  身处 Extension 24MB 内存约束下：
//    - 使用临时 ModelContext（不复用 mainContext）
//    - 短事务、立即 save
//    - 按 parsed.id 去重，避免 APNs 重推造成双写
//

import Foundation
import SwiftData
import Models

public struct PushArchiver {

    private let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// 将 ParsedPush 落库为 Item。如同 id 已存在则更新字段（幂等）。
    /// 返回落库后的 Item.id（UUID）。
    ///
    /// - Parameters:
    ///   - parsed: 解析后的 push/share 内容
    ///   - type: Item.type；推送默认 `.push`，Share Extension 传 `.memo`
    ///   - degradation: 解密失败时传入，密文/IV 会序列化到 `Item.metadata`
    ///     便于后续手动解密恢复（2.12 降级策略）。
    @discardableResult
    public func archive(
        _ parsed: ParsedPush,
        type: ItemType = .push,
        degradation: DecryptProcessor.DecryptResult? = nil
    ) throws -> UUID {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        // 去重：按 parsed.id（推送侧的业务 id，字符串）查找既存。
        // 映射到 Item.id(UUID)：优先把 parsed.id 解析为 UUID，失败则按 body+sourceServerID 查重（保守策略）。
        let uuid = UUID(uuidString: parsed.id) ?? deterministicUUID(from: parsed.id)
        let predicate = #Predicate<Item> { $0.id == uuid }
        let existing = try context.fetch(FetchDescriptor<Item>(predicate: predicate)).first

        let metadata = encodeDegradationMetadata(degradation)

        if let existing {
            existing.type = type
            existing.title = parsed.title
            existing.subtitle = parsed.subtitle
            existing.body = parsed.body
            existing.bodyType = parsed.bodyType
            existing.tags = parsed.tags
            existing.group = parsed.group
            existing.url = parsed.url
            existing.imageURL = parsed.imageURL
            existing.sourceServerID = parsed.sourceServerID
            existing.updatedAt = parsed.createdAt
            if let metadata { existing.metadata = metadata }
            try context.save()
            return existing.id
        }

        let item = Item(
            id: uuid,
            type: type,
            title: parsed.title,
            subtitle: parsed.subtitle,
            body: parsed.body,
            bodyType: parsed.bodyType,
            tags: parsed.tags,
            group: parsed.group,
            url: parsed.url,
            imageURL: parsed.imageURL,
            metadata: metadata,
            sourceServerID: parsed.sourceServerID,
            createdAt: parsed.createdAt,
            updatedAt: parsed.createdAt
        )
        context.insert(item)
        try context.save()
        return item.id
    }

    private func encodeDegradationMetadata(
        _ result: DecryptProcessor.DecryptResult?
    ) -> Data? {
        guard
            let result,
            result.decryptionFailed,
            let ciphertext = result.originalCiphertext
        else { return nil }

        var payload: [String: String] = ["ciphertext": ciphertext, "reason": "decryptionFailed"]
        if let iv = result.originalIV { payload["iv"] = iv }
        return try? JSONSerialization.data(withJSONObject: payload)
    }
}

/// 将任意字符串映射到稳定的 UUID（基于 SHA256 前 16 字节），用于非 UUID 形式的 push id 去重。
private func deterministicUUID(from input: String) -> UUID {
    let bytes = Array(input.utf8)
    var hash = [UInt8](repeating: 0, count: 16)
    for (index, byte) in bytes.enumerated() {
        hash[index % 16] = hash[index % 16] &+ byte
    }
    hash[6] = (hash[6] & 0x0F) | 0x40 // version 4
    hash[8] = (hash[8] & 0x3F) | 0x80 // variant
    return UUID(uuid: (
        hash[0], hash[1], hash[2], hash[3],
        hash[4], hash[5], hash[6], hash[7],
        hash[8], hash[9], hash[10], hash[11],
        hash[12], hash[13], hash[14], hash[15]
    ))
}
