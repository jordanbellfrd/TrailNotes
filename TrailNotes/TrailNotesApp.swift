import SwiftUI

@main
struct TrailNotesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var storage = LocalStorage()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storage)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static var shared: AppDelegate?
    let domain: String = "https://pathlog.fun"

    private let appID = "6760856369"
    private let decryptionKey = "usOQt6Cu79GWyXvqFvP8mwSfJ8H03cRz"
    private let endpoint = "https://pathlog.fun/api"

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        DataCollectorAttribution.shared.initialize(appID: appID, decryptionKey: decryptionKey, endpoint: endpoint) { success in
            if success {
                DataCollectorAttribution.shared.requestPermissions()
            }
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        DataCollectorAttribution.shared.setPushToken(token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }

    // MARK: - Foreground Push
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        if let data = userInfo as? [String: Any], let pushId = data["pushId"] as? String {
            sendDeliveredEvent(pushId: pushId)
        }
        savePushToStorage(notification: notification.request)
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - Push Tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let data = userInfo as? [String: Any], let pushId = data["pushId"] as? String {
            sendOpenedEvent(pushId: pushId)
        }
        completionHandler()
    }

    // MARK: - Push Events
    private func sendDeliveredEvent(pushId: String) {
        let urlString = "\(domain)/push-event/\(pushId)/delivered"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    private func sendOpenedEvent(pushId: String) {
        let urlString = "\(domain)/push-event/\(pushId)/opened"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    // MARK: - Save Push to Storage
    private func savePushToStorage(notification: UNNotificationRequest) {
        let storedPush = StoredPush(from: notification)
        PushStorageService.shared.savePush(storedPush)
    }
}
