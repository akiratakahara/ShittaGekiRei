import SwiftUI
import UserNotifications

@main
struct ShittaGekiReiApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - AppDelegate (UNUserNotificationCenterDelegate)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // 通知をフォアグラウンドでも表示
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 次回の通知メッセージを新しい内容で再スケジュール
        NotificationManager.shared.scheduleAll()
        completionHandler([.banner, .sound, .badge])
    }

    // 通知タップ時の処理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let modeRaw = userInfo["mode"] as? String,
           let mode = NotificationMode(rawValue: modeRaw) {
            // アプリ起動後にアラーム鳴動
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AlarmManager.shared.startRinging(mode: mode)
            }
        }
        // 次回の通知メッセージを新しい内容で再スケジュール
        NotificationManager.shared.scheduleAll()
        completionHandler()
    }
}
