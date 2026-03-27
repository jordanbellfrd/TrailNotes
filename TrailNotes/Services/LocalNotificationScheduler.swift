import Foundation
import UserNotifications

// MARK: - Local Notification Scheduler
class LocalNotificationScheduler {
    static let shared = LocalNotificationScheduler()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let maxNotifications = 64 // iOS limit
    private let categoryIdentifier = "BANNED_APP_PUSH"
    
    private init() {
        setupNotificationCategories()
    }
    
    // MARK: - Setup Categories
    private func setupNotificationCategories() {
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        notificationCenter.setNotificationCategories([category])
    }
    
    // MARK: - Schedule Notifications with Calendar (PRODUCTION MODE)
    func scheduleNotificationsWithSchedule(schedules: [PushSchedule], templates: [StoredPush], completion: @escaping (Bool) -> Void) {
        // Clear existing scheduled notifications first
        cancelAllScheduledNotifications()
        
        guard !schedules.isEmpty, !templates.isEmpty else {
            print("⚠️ [LocalScheduler] No schedules or templates provided")
            completion(false)
            return
        }
        
        print("📅 [LocalScheduler] Scheduling \(schedules.count) calendar-based notifications...")
        
        var scheduledCount = 0
        let totalSchedules = schedules.count
        
        for (index, schedule) in schedules.enumerated() {
            let template = schedule.useRandomTemplate == true ? templates.randomElement() : templates.first
            
            guard let template = template else {
                print("⚠️ [LocalScheduler] No template available for schedule \(schedule.id ?? "unknown")")
                if index == totalSchedules - 1 {
                    completion(scheduledCount > 0)
                }
                continue
            }
            
            scheduleCalendarNotification(for: template, schedule: schedule) { success in
                if success {
                    scheduledCount += 1
                }
                
                // Check if all scheduled
                if index == totalSchedules - 1 {
                    print("✅ [LocalScheduler] Scheduled \(scheduledCount)/\(totalSchedules) calendar notifications")
                    completion(scheduledCount > 0)
                }
            }
        }
    }
    
    // MARK: - Schedule Calendar Notification
    private func scheduleCalendarNotification(for push: StoredPush, schedule: PushSchedule, completion: @escaping (Bool) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = push.title ?? "Notification"
        content.body = push.body ?? ""
        
        if let badge = push.badge {
            content.badge = NSNumber(value: badge)
        }
        
        if let sound = push.sound {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
        } else {
            content.sound = .default
        }
        
        content.categoryIdentifier = categoryIdentifier
        
        // Add custom payload
        if let customPayload = push.customPayload {
            content.userInfo = customPayload
        }
        
        // MARK: - Determine time (useLastActiveTime logic)
        var hour: Int
        var minute: Int
        
        if schedule.useLastActiveTime == true {
            // 🎯 Use last active time from SessionService
            if let lastActiveTime = SessionService.shared.getLastActiveTimeComponents() {
                hour = lastActiveTime.hour
                minute = lastActiveTime.minute
                print("⏰ [LocalScheduler] Using last active time: \(String(format: "%02d:%02d", hour, minute))")
            } else {
                // Fallback to schedule time if no last active time
                if let timeString = schedule.time, let parsedTime = parseTime(timeString) {
                    hour = parsedTime.hour
                    minute = parsedTime.minute
                    print("⚠️ [LocalScheduler] No last active time, using schedule time: \(timeString)")
                } else {
                    // Final fallback to default time (09:00)
                    hour = 9
                    minute = 0
                    print("⚠️ [LocalScheduler] No time available, using default: 09:00")
                }
            }
        } else {
            // 📅 Use schedule time (normal mode)
            if let timeString = schedule.time, let parsedTime = parseTime(timeString) {
                hour = parsedTime.hour
                minute = parsedTime.minute
                print("📅 [LocalScheduler] Using schedule time: \(timeString)")
            } else {
                // Fallback to default time if schedule.time is nil
                hour = 9
                minute = 0
                print("⚠️ [LocalScheduler] No schedule time, using default: 09:00")
            }
        }
        
        // Create date components for trigger
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        // Add day of week if specified (1 = Sunday in iOS, but API uses 0 = Sunday)
        if let dayOfWeek = schedule.dayOfWeek {
            dateComponents.weekday = dayOfWeek + 1 // Convert API format (0-6) to iOS format (1-7)
        }
        
        // Create calendar trigger with repeating
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: schedule.type == "weekly"
        )
        
        let request = UNNotificationRequest(
            identifier: "schedule_\(schedule.id ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ [LocalScheduler] Failed to schedule calendar notification: \(error.localizedDescription)")
                completion(false)
            } else {
                let dayName = schedule.dayOfWeek != nil ? self.getDayName(schedule.dayOfWeek!) : "daily"
                let timeFormatted = String(format: "%02d:%02d", hour, minute)
                print("✅ [LocalScheduler] Scheduled: \(dayName) at \(timeFormatted)")
                completion(true)
            }
        }
    }
    
    // MARK: - Parse Time String
    private func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]),
              hour >= 0 && hour < 24,
              minute >= 0 && minute < 60 else {
            return nil
        }
        return (hour, minute)
    }
    
    // MARK: - Get Day Name
    private func getDayName(_ dayOfWeek: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[min(max(dayOfWeek, 0), 6)]
    }
    
    // MARK: - Schedule Notifications from Storage (TEST MODE - 5 sec interval)
    func scheduleNotificationsFromStorage(completion: @escaping (Bool) -> Void) {
        // Clear existing scheduled notifications first
        cancelAllScheduledNotifications()
        
        let pushes = PushStorageService.shared.loadPushes()
        
        guard !pushes.isEmpty else {
            print("⚠️ [LocalScheduler] No pushes to schedule")
            completion(false)
            return
        }
        
        // Take up to 60 pushes (leave 4 slots for system)
        let pushesToSchedule = Array(pushes.prefix(60))
        
        print("📅 [LocalScheduler] Scheduling \(pushesToSchedule.count) local notifications...")
        
        var scheduledCount = 0
        
        for (index, push) in pushesToSchedule.enumerated() {
            scheduleNotification(for: push, delay: TimeInterval(index * 5)) { success in
                if success {
                    scheduledCount += 1
                }
                
                // Check if all scheduled
                if index == pushesToSchedule.count - 1 {
                    print("✅ [LocalScheduler] Scheduled \(scheduledCount)/\(pushesToSchedule.count) notifications")
                    completion(scheduledCount > 0)
                }
            }
        }
    }
    
    // MARK: - Schedule Single Notification
    private func scheduleNotification(for push: StoredPush, delay: TimeInterval, completion: @escaping (Bool) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = push.title ?? "Notification"
        content.body = push.body ?? ""
        
        if let badge = push.badge {
            content.badge = NSNumber(value: badge)
        }
        
        if let sound = push.sound {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
        } else {
            content.sound = .default
        }
        
        content.categoryIdentifier = categoryIdentifier
        
        // Add custom payload
        if let customPayload = push.customPayload {
            content.userInfo = customPayload
        }
        
        // Schedule with delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "local_\(push.id)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ [LocalScheduler] Failed to schedule: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    // MARK: - Cancel All Scheduled
    func cancelAllScheduledNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("🗑️ [LocalScheduler] Cancelled all pending notifications")
    }
    
    // MARK: - Get Pending Count
    func getPendingNotificationsCount(completion: @escaping (Int) -> Void) {
        notificationCenter.getPendingNotificationRequests { requests in
            let localRequests = requests.filter { $0.identifier.hasPrefix("local_") }
            completion(localRequests.count)
        }
    }
    
    // MARK: - Request Permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ [LocalScheduler] Permission error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            print(granted ? "✅ [LocalScheduler] Permission granted" : "⚠️ [LocalScheduler] Permission denied")
            completion(granted)
        }
    }
}


