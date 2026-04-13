import UserNotifications
import Foundation

// MARK: - Schedule Entry (ユーザーがカスタマイズ可能な通知スケジュール)
struct ScheduleEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var mode: String          // NotificationMode.rawValue
    var weekday: Int          // 1=Sun 2=Mon ... 7=Sat
    var hour: Int
    var minute: Int
    var isEnabled: Bool = true

    var modeEnum: NotificationMode? { NotificationMode(rawValue: mode) }

    var weekdayName: String {
        let names = ["", "日", "月", "火", "水", "木", "金", "土"]
        return names[weekday]
    }

    var timeString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var schedules: [ScheduleEntry] = []

    private let storageKey = "shittagekirei.schedules"

    init() {
        loadSchedules()
    }

    // MARK: - Persistence
    func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ScheduleEntry].self, from: data) {
            schedules = decoded
        } else {
            // デフォルトスケジュール
            schedules = [
                ScheduleEntry(mode: "monday",   weekday: 2, hour: 6,  minute: 0),
                ScheduleEntry(mode: "thursday",  weekday: 5, hour: 6,  minute: 0),
                ScheduleEntry(mode: "friday",    weekday: 6, hour: 20, minute: 0),
            ]
            saveSchedules()
        }
    }

    func saveSchedules() {
        if let encoded = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    // MARK: - Authorization
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { self.isAuthorized = granted }
            if granted { scheduleAll() }
        } catch {
            print("Notification auth error: \(error)")
        }
    }

    func checkAuthorization() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Schedule All
    func scheduleAll() {
        let center = UNUserNotificationCenter.current()
        // 既存の定期通知をすべてキャンセル
        let ids = schedules.map { "shittagekirei.schedule.\($0.id.uuidString)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        for entry in schedules where entry.isEnabled {
            scheduleEntry(entry)
        }
        print("✅ 叱咤激励: \(schedules.filter(\.isEnabled).count)件の通知をスケジュール")
    }

    func cancelAll() {
        let ids = schedules.map { "shittagekirei.schedule.\($0.id.uuidString)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        print("🚫 叱咤激励: 通知キャンセル")
    }

    // MARK: - Schedule Single Entry
    private func scheduleEntry(_ entry: ScheduleEntry) {
        guard let mode = entry.modeEnum else { return }

        let id = "shittagekirei.schedule.\(entry.id.uuidString)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let message = MessageBank.random(for: mode)

        // 音声ファイルを事前生成してから通知をスケジュール
        SpeechGenerator.shared.generateSpeech(message: message, id: entry.id.uuidString) { filename in
            let content = UNMutableNotificationContent()
            content.title = mode.notificationTitle
            content.body  = message
            content.interruptionLevel = .timeSensitive
            content.userInfo = ["mode": mode.rawValue]

            // カスタム音声が生成できた場合はそれを使用、なければデフォルト
            if let filename = filename {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(filename))
            } else {
                content.sound = .defaultCritical
            }

            var components = DateComponents()
            components.weekday = entry.weekday
            components.hour    = entry.hour
            components.minute  = entry.minute
            components.second  = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            center.add(request) { error in
                if let error { print("Notification schedule error [\(id)]: \(error)") }
            }
        }
    }

    // MARK: - Add / Remove / Toggle
    func addSchedule(mode: NotificationMode, weekday: Int, hour: Int, minute: Int) {
        let entry = ScheduleEntry(mode: mode.rawValue, weekday: weekday, hour: hour, minute: minute)
        schedules.append(entry)
        saveSchedules()
        scheduleEntry(entry)
    }

    func removeSchedule(id: UUID) {
        let notifID = "shittagekirei.schedule.\(id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifID])
        schedules.removeAll { $0.id == id }
        saveSchedules()
    }

    func toggleSchedule(id: UUID) {
        guard let idx = schedules.firstIndex(where: { $0.id == id }) else { return }
        schedules[idx].isEnabled.toggle()
        saveSchedules()
        if schedules[idx].isEnabled {
            scheduleEntry(schedules[idx])
        } else {
            let notifID = "shittagekirei.schedule.\(id.uuidString)"
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notifID])
        }
    }

    // MARK: - Debug
    func listPending() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
}
