//
//  PushParser.swift
//  BarkService
//
//  解析 APNs userInfo → ParsedPush 值类型。
//  协议参考：doc/bark-protocol.md（字段全部小写归一）。
//

import Foundation
import Models

public struct ParsedPush: Sendable, Equatable, Codable {
    public let id: String
    public let title: String?
    public let subtitle: String?
    public let body: String
    public let bodyType: BodyType
    public let tags: [String]
    public let group: String?
    public let url: String?
    public let imageURL: String?
    public let ciphertext: String?
    public let sourceServerID: UUID?
    public let createdAt: Date

    public init(
        id: String,
        title: String? = nil,
        subtitle: String? = nil,
        body: String,
        bodyType: BodyType = .plainText,
        tags: [String] = [],
        group: String? = nil,
        url: String? = nil,
        imageURL: String? = nil,
        ciphertext: String? = nil,
        sourceServerID: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.bodyType = bodyType
        self.tags = tags
        self.group = group
        self.url = url
        self.imageURL = imageURL
        self.ciphertext = ciphertext
        self.sourceServerID = sourceServerID
        self.createdAt = createdAt
    }
}

public enum PushParser {

    /// 解析 APNs userInfo。字段名大小写不敏感（与 bark-server 一致）。
    public static func parse(
        userInfo: [AnyHashable: Any],
        sourceServerID: UUID? = nil,
        now: Date = .now
    ) -> ParsedPush {
        let lowered = lowercaseKeys(userInfo)
        let aps = (lowered["aps"] as? [AnyHashable: Any]).map(lowercaseKeys) ?? [:]
        let alert = (aps["alert"] as? [AnyHashable: Any]).map(lowercaseKeys) ?? [:]

        let title = pickString(alert, "title")
        let subtitle = pickString(alert, "subtitle")

        let markdown = pickString(lowered, "markdown")
        let alertBody = pickString(alert, "body")
        let bodyText: String
        let bodyType: BodyType
        if let markdown, !markdown.isEmpty {
            bodyText = markdown
            bodyType = .markdown
        } else {
            bodyText = alertBody ?? ""
            bodyType = .plainText
        }

        let id = pickString(lowered, "id") ?? UUID().uuidString
        let group = pickString(lowered, "group")
        let url = pickString(lowered, "url")
        let imageURL = pickString(lowered, "image")
        let ciphertext = pickString(lowered, "ciphertext")
        let tags = extractTags(from: bodyText)

        return ParsedPush(
            id: id,
            title: title,
            subtitle: subtitle,
            body: bodyText,
            bodyType: bodyType,
            tags: tags,
            group: group,
            url: url,
            imageURL: imageURL,
            ciphertext: ciphertext,
            sourceServerID: sourceServerID,
            createdAt: now
        )
    }

    /// 从 body 中抽取 `#tag` 形式的标签。
    /// 规则：`#` 紧跟 1+ 非空白非 `#` 字符；去重、保留首次出现顺序。
    public static func extractTags(from body: String) -> [String] {
        guard !body.isEmpty else { return [] }
        var result: [String] = []
        var seen: Set<String> = []
        let scanner = Scanner(string: body)
        scanner.charactersToBeSkipped = nil

        while !scanner.isAtEnd {
            _ = scanner.scanUpToString("#")
            guard scanner.scanString("#") != nil else { break }
            guard let tag = scanner.scanCharacters(from: tagCharacterSet), !tag.isEmpty else {
                continue
            }
            if !seen.contains(tag) {
                seen.insert(tag)
                result.append(tag)
            }
        }
        return result
    }

    private static let tagCharacterSet: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "_-")
        set.formUnion(CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}"))
        return set
    }()
}

// MARK: - Helpers

private func lowercaseKeys(_ dict: [AnyHashable: Any]) -> [AnyHashable: Any] {
    var out: [AnyHashable: Any] = [:]
    for (key, value) in dict {
        if let stringKey = key as? String {
            out[stringKey.lowercased()] = value
        } else {
            out[key] = value
        }
    }
    return out
}

private func pickString(_ dict: [AnyHashable: Any], _ key: String) -> String? {
    guard let value = dict[key] else { return nil }
    if let stringValue = value as? String, !stringValue.isEmpty {
        return stringValue
    }
    return nil
}
