//
//  SoundCatalog.swift
//  Store
//
//  Bark 官方声音清单(静态硬编码)。App 试听与 NSE 推送共享同一份 id↔文件名映射。
//  文件本体位于各 target main bundle 根目录(见 Shared/Sounds + project.yml)。
//

import Foundation

public struct AlertSound: Identifiable, Hashable, Sendable {
    public let id: String           // e.g. "bell";系统默认为 "__system__"
    public let displayName: String  // e.g. "Bell"
    public let fileName: String     // e.g. "bell.caf";系统默认为 ""

    public init(id: String, displayName: String, fileName: String) {
        self.id = id
        self.displayName = displayName
        self.fileName = fileName
    }
}

public enum SoundCatalog {

    /// 伪 id:表示"用系统默认/不覆盖发送方声音"。
    public static let systemDefaultID = "__system__"
    /// 到达但不响。
    public static let silenceID = "silence"

    public static let systemDefault = AlertSound(
        id: systemDefaultID, displayName: "System default", fileName: ""
    )

    /// Bark 官方声音的 id(= 文件名去扩展名),与 Shared/Sounds 目录一致。
    private static let barkIDs = [
        "alarm", "anticipate", "bell", "birdsong", "bloom", "calypso", "chime",
        "choo", "descent", "electronic", "fanfare", "glass", "gotosleep",
        "healthnotification", "horn", "ladder", "mailsent", "minuet",
        "multiwayinvitation", "newmail", "newsflash", "noir", "paymentsuccess",
        "shake", "sherwoodforest", "silence", "spell", "suspense", "telegraph",
        "tiptoes", "typewriters", "update"
    ]

    public static let barkSounds: [AlertSound] = barkIDs.map { id in
        AlertSound(id: id, displayName: displayName(for: id), fileName: "\(id).caf")
    }

    /// 展示用清单:系统默认置顶,其后为全部 Bark 声音。
    public static let all: [AlertSound] = [systemDefault] + barkSounds

    public static func sound(for id: String) -> AlertSound? {
        all.first { $0.id == id }
    }

    /// id → 展示名。特殊拼写单独处理,其余首字母大写。
    private static func displayName(for id: String) -> String {
        switch id {
        case "healthnotification": return "Health notification"
        case "multiwayinvitation": return "Multiway invitation"
        case "paymentsuccess": return "Payment success"
        case "sherwoodforest": return "Sherwood forest"
        case "gotosleep": return "Go to sleep"
        case "newmail": return "New mail"
        case "mailsent": return "Mail sent"
        case "newsflash": return "News flash"
        default: return id.prefix(1).uppercased() + id.dropFirst()
        }
    }
}
