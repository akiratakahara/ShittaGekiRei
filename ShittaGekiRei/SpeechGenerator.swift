import AVFoundation
import Foundation

/// 叱咤激励メッセージを音声ファイルに変換し、通知サウンドとして使えるようにする
final class SpeechGenerator {

    static let shared = SpeechGenerator()

    private let synthesizer = AVSpeechSynthesizer()
    private let soundsDir: URL = {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let dir = lib.appendingPathComponent("Sounds")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// メッセージを音声ファイルに変換して保存し、ファイル名を返す
    func generateSpeech(message: String, id: String, completion: @escaping (String?) -> Void) {
        let filename = "alarm_\(id).caf"
        let fileURL = soundsDir.appendingPathComponent(filename)

        // 既にファイルがあれば削除して再生成
        try? FileManager.default.removeItem(at: fileURL)

        let text = message.replacingOccurrences(of: "\n", with: "。")
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.15
        utterance.volume = 1.0

        // iOS 16+: AVSpeechSynthesizer.write() で音声をファイルに書き出す
        var audioBuffers: [AVAudioPCMBuffer] = []

        synthesizer.write(utterance) { buffer in
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer, pcmBuffer.frameLength > 0 else {
                // バッファ終了 → ファイルに保存
                self.saveBuffers(audioBuffers, to: fileURL, maxDuration: 29.0)
                completion(filename)
                return
            }
            audioBuffers.append(pcmBuffer)
        }
    }

    /// 複数のPCMバッファをCAFファイルに保存（最大秒数制限付き）
    private func saveBuffers(_ buffers: [AVAudioPCMBuffer], to url: URL, maxDuration: Double) {
        guard let firstBuffer = buffers.first else { return }
        let format = firstBuffer.format
        let maxFrames = AVAudioFrameCount(maxDuration * format.sampleRate)

        guard let file = try? AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        ) else {
            print("❌ 音声ファイル作成失敗: \(url)")
            return
        }

        var totalFrames: AVAudioFrameCount = 0
        for buffer in buffers {
            let remaining = maxFrames - totalFrames
            if remaining <= 0 { break }

            if buffer.frameLength <= remaining {
                try? file.write(from: buffer)
                totalFrames += buffer.frameLength
            } else {
                // 残りフレーム分だけ書き込む
                if let trimmed = trimBuffer(buffer, to: remaining) {
                    try? file.write(from: trimmed)
                    totalFrames += remaining
                }
                break
            }
        }
        print("✅ 音声ファイル生成: \(url.lastPathComponent) (\(String(format: "%.1f", Double(totalFrames) / format.sampleRate))秒)")
    }

    private func trimBuffer(_ buffer: AVAudioPCMBuffer, to frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let trimmed = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: frameCount) else { return nil }
        trimmed.frameLength = frameCount
        let bytesPerFrame = Int(buffer.format.streamDescription.pointee.mBytesPerFrame)
        let size = Int(frameCount) * bytesPerFrame
        for ch in 0..<Int(buffer.format.channelCount) {
            memcpy(trimmed.floatChannelData?[ch], buffer.floatChannelData?[ch], size)
        }
        return trimmed
    }

    /// 特定IDのサウンドファイル名を返す（存在確認付き）
    func soundFilename(for id: String) -> String? {
        let filename = "alarm_\(id).caf"
        let fileURL = soundsDir.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path) ? filename : nil
    }

    /// 全サウンドファイルを削除
    func cleanUp() {
        let files = (try? FileManager.default.contentsOfDirectory(at: soundsDir, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "caf" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
