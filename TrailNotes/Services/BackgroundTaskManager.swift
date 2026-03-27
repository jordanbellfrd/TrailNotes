import Foundation

// MARK: - Manual Ban Check Manager
// NOTE: Background tasks были удалены - проверка бана только при запуске приложения
class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private init() {}
    
    // MARK: - Manual Ban Check (used on app launch and in Debug panel)
    func performManualBanCheck(completion: @escaping (Bool, Bool) -> Void) {
        guard let domain = AppDelegate.shared?.domain else {
            print("❌ [Manual Check] Domain not available")
            completion(false, false)
            return
        }
        
        print("🔍 [Manual Check] Starting ban check for domain: \(domain)")
        
        BanStatusService.shared.checkBanStatus(domain: domain) { result in
            switch result {
            case .success(let response):
                BanStatusService.shared.saveLastCheckTime()
                
                if response.isBanned {
                    print("⚠️ [Manual Check] App IS BANNED")
                    
                    // Save pushes from server if available (API response)
                    if let pushes = response.pushes, !pushes.isEmpty {
                        PushStorageService.shared.savePushes(from: pushes, clearOld: true)
                        print("💾 [Manual Check] Saved \(pushes.count) pushes from API")
                    }
                    
                    // Get stored pushes (templates) - может быть из API или из кэша
                    let storedPushes = PushStorageService.shared.loadPushes()
                    
                    if storedPushes.isEmpty {
                        print("⚠️ [Manual Check] No pushes available for scheduling")
                        completion(true, false)
                        return
                    }
                    
                    // Schedule notifications based on schedule type
                    if let schedules = response.schedules, !schedules.isEmpty {
                        print("📅 [Manual Check] Using CALENDAR scheduling (\(schedules.count) schedules)")
                        LocalNotificationScheduler.shared.scheduleNotificationsWithSchedule(
                            schedules: schedules,
                            templates: storedPushes
                        ) { success in
                            completion(true, success)
                        }
                    } else {
                        print("📅 [Manual Check] No schedules, using TEST mode (5 sec interval)")
                        LocalNotificationScheduler.shared.scheduleNotificationsFromStorage { success in
                            completion(true, success)
                        }
                    }
                } else {
                    print("✅ [Manual Check] App is NOT banned")
                    // Cancel any scheduled local notifications
                    LocalNotificationScheduler.shared.cancelAllScheduledNotifications()
                    completion(false, true)
                }
                
            case .failure(let error):
                print("❌ [Manual Check] Ban check failed: \(error.localizedDescription)")
                completion(false, false)
            }
        }
    }
}
