//
//  SoundPreviewPlayer.swift
//  BarkAgent
//
//  声音选择屏的即时试听。用 AVAudioPlayer 播放 bundle 内 .caf。
//  设 .playback category,使真机静音开关下试听仍出声。
//

import AVFoundation
import os

@MainActor
final class SoundPreviewPlayer {

    static let shared = SoundPreviewPlayer()

    private static let log = Logger(subsystem: "com.barkagent.ios", category: "sound-preview")

    private var player: AVAudioPlayer?

    private init() {}

    /// 播放指定 .caf。空文件名(系统默认)不播;silence 不播。
    func play(fileName: String) {
        guard !fileName.isEmpty, fileName != "silence.caf" else {
            player?.stop()
            return
        }
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            Self.log.error("preview sound not found in bundle: \(fileName, privacy: .public)")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            player?.stop()
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
        } catch {
            Self.log.error("preview playback failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
