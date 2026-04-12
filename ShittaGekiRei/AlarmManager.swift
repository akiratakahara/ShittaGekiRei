import Foundation
import AVFoundation
import AudioToolbox

/// フォアグラウンド時のアラーム鳴動 ＋ 音声読み上げ
/// スケジュールはNotificationManagerで一元管理
final class AlarmManager: ObservableObject {

    static let shared = AlarmManager()

    private var speechSynthesizer = AVSpeechSynthesizer()
    private var pollingTimer: Timer?
    private var beepTimer: Timer?

    @Published var isRinging = false
    @Published var currentSpokenMessage = ""
    @Published var ringingMode: NotificationMode?

    // 同じ分に二重発火しないための記録
    private var lastFiredKey = ""

    // MARK: - Ring
    func startRinging(mode: NotificationMode) {
        guard !isRinging else { return }
        isRinging = true
        ringingMode = mode

        configureAudioSession()

        // バイブレーション（繰り返し）
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        beepTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }

        // 即座に叱咤激励メッセージを読み上げ
        speakMessage(mode: mode)
    }

    func stopRinging() {
        isRinging = false
        ringingMode = nil
        currentSpokenMessage = ""
        beepTimer?.invalidate()
        beepTimer = nil
        speechSynthesizer.stopSpeaking(at: .immediate)
        deactivateAudioSession()
    }

    // MARK: - AVSpeechSynthesizer (叱咤激励読み上げ)
    private func speakMessage(mode: NotificationMode) {
        let msg = MessageBank.random(for: mode)
        currentSpokenMessage = msg

        let text = msg.replacingOccurrences(of: "\n", with: "。")

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.15
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.3

        speechSynthesizer.speak(utterance)
    }

    // MARK: - Audio Session
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Polling (フォアグラウンド時にスケジュールをチェック)
    func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkSchedules()
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkSchedules() {
        let now = Date()
        let cal = Calendar.current
        let nowH = cal.component(.hour, from: now)
        let nowM = cal.component(.minute, from: now)
        let nowWD = cal.component(.weekday, from: now)

        // 同じ分に二度鳴らさない
        let currentKey = "\(nowWD)-\(nowH)-\(nowM)"
        guard currentKey != lastFiredKey else { return }

        for schedule in NotificationManager.shared.schedules where schedule.isEnabled {
            if schedule.weekday == nowWD &&
               schedule.hour == nowH &&
               schedule.minute == nowM {
                if let mode = schedule.modeEnum {
                    lastFiredKey = currentKey
                    DispatchQueue.main.async { self.startRinging(mode: mode) }
                    return
                }
            }
        }
    }
}
