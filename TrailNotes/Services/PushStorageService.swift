import Foundation
import UserNotifications

// MARK: - Stored Push Model
struct StoredPush: Codable {
    let id: String
    let title: String?
    let body: String?
    let badge: Int?
    let sound: String?
    let customPayload: [String: String]?
    let receivedAt: Date
    
    init(from notification: UNNotificationRequest) {
        self.id = notification.identifier
        self.title = notification.content.title
        self.body = notification.content.body
        self.badge = notification.content.badge?.intValue
        self.sound = notification.content.sound?.debugDescription
        
        // Extract custom payload
//        var payload: [String: String] = [:]
//        for (key, value) in notification.content.userInfo {
//            if let stringValue = value as? String {
//                payload[key] = stringValue
//            } else if let dictValue = value as? [String: Any] {
//                // Convert nested dict to JSON string
//                if let jsonData = try? JSONSerialization.data(withJSONObject: dictValue),
//                   let jsonString = String(data: jsonData, encoding: .utf8) {
//                    payload[key] = jsonString
//                }
//            }
//        }
        self.customPayload = /*payload.isEmpty ? nil : payload*/ nil
        self.receivedAt = Date()
    }
    
    init(from serverPush: ServerPush) {
        self.id = serverPush.id ?? UUID().uuidString
        self.title = serverPush.title
        self.body = serverPush.body
        self.badge = serverPush.badge
        self.sound = serverPush.sound
        self.customPayload = serverPush.customPayload
        self.receivedAt = Date()
    }
}

// MARK: - Server Push Model
struct ServerPush: Codable {
    let id: String?
    let title: String?
    let body: String?
    let badge: Int?
    let sound: String?
    let customPayload: [String: String]?
}

// MARK: - Push Storage Service
class PushStorageService {
    static let shared = PushStorageService()
    
    private let maxPushes = 60
    private let storageKey = "stored_pushes"
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Save Push
    func savePush(_ push: StoredPush) {
        var pushes = loadPushes()
        
        // Add new push at the beginning
        pushes.insert(push, at: 0)
        
        // Keep only last 60
        if pushes.count > maxPushes {
            pushes = Array(pushes.prefix(maxPushes))
        }
        
        savePushes(pushes)
        
        print("✅ [PushStorage] Saved push. Total: \(pushes.count)/\(maxPushes)")
    }
    
    // MARK: - Save Multiple Pushes
    func savePushes(from serverPushes: [ServerPush], clearOld: Bool = true) {
        var pushes = clearOld ? [] : loadPushes()
        
        // Convert server pushes to stored pushes
        let newPushes = serverPushes.map { StoredPush(from: $0) }
        
        // Add new pushes
        pushes.insert(contentsOf: newPushes, at: 0)
        
        // Keep only last 60
        if pushes.count > maxPushes {
            pushes = Array(pushes.prefix(maxPushes))
        }
        
        savePushes(pushes)
        
        print("✅ [PushStorage] Saved \(newPushes.count) pushes from server. Total: \(pushes.count)/\(maxPushes)")
    }
    
    // MARK: - Load Pushes
    func loadPushes() -> [StoredPush] {
        guard let data = defaults.data(forKey: storageKey),
              let pushes = try? JSONDecoder().decode([StoredPush].self, from: data) else {
            return []
        }
        return pushes
    }
    
    // MARK: - Clear All
    func clearAll() {
        defaults.removeObject(forKey: storageKey)
        print("🗑️ [PushStorage] Cleared all pushes")
    }
    
    // MARK: - Get Count
    func getPushCount() -> Int {
        return loadPushes().count
    }
    
    // MARK: - Private Save
    private func savePushes(_ pushes: [StoredPush]) {
        if let data = try? JSONEncoder().encode(pushes) {
            defaults.set(data, forKey: storageKey)
        }
    }
    
    // MARK: - Schedule Cache (Fallback)
    private let scheduleCacheKey = "cached_schedules"
    
    /// Сохранить schedules как fallback (используется при ошибках API)
    func cacheSchedules(_ schedules: [PushSchedule]) {
        if let data = try? JSONEncoder().encode(schedules) {
            defaults.set(data, forKey: scheduleCacheKey)
            print("💾 [PushStorage] Cached \(schedules.count) schedules for fallback")
        }
    }
    
    /// Загрузить закэшированные schedules (fallback при ошибках API)
    func loadCachedSchedules() -> [PushSchedule]? {
        guard let data = defaults.data(forKey: scheduleCacheKey) else {
            print("⚠️ [PushStorage] No cached schedules found")
            return nil
        }
        
        if let schedules = try? JSONDecoder().decode([PushSchedule].self, from: data) {
            print("✅ [PushStorage] Loaded \(schedules.count) cached schedules")
            return schedules
        }
        
        return nil
    }
    
    /// Очистить кэш schedules
    func clearCachedSchedules() {
        defaults.removeObject(forKey: scheduleCacheKey)
        print("🗑️ [PushStorage] Cleared cached schedules")
    }
}


