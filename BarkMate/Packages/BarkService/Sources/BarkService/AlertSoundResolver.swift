//
//  AlertSoundResolver.swift
//  BarkService
//
//  纯决策函数:给定 APNs userInfo + 声音偏好,决定 NSE 该如何设置 content.sound。
//  抽成纯函数以便脱离 UNNotification runtime 单测。
//

import Foundation
import Store

public enum SoundDecision: Equatable, Sendable {
    case keep               // 不覆盖发送方声音
    case silence            // content.sound = nil
    case named(String)      // UNNotificationSound(named: fileName)
}

public enum AlertSoundResolver {

    public static func decide(
        userInfo: [AnyHashable: Any],
        defaults: UserDefaults? = nil
    ) -> SoundDecision {
        let parsed = PushParser.parse(userInfo: userInfo)
        guard let status = parsed.agentStatus else { return .keep }

        let store = AlertSoundStore(defaults: defaults)
        guard let id = store.resolvedSoundID(for: status) else { return .keep }
        guard id != SoundCatalog.systemDefaultID else { return .keep }
        guard let sound = SoundCatalog.sound(for: id) else { return .keep }

        if sound.id == SoundCatalog.silenceID { return .silence }
        return .named(sound.fileName)
    }
}
