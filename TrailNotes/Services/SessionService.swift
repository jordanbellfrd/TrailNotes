import UIKit

class SessionService {
    static let shared = SessionService()
    
    private let userDefaults = SecureUserDefaults.standard
    private let sessionCountKey = "countforsessions"
    private let lifetimeSessionCountKey = "userlifetimekey"
    private let lastSessionTimeKey = "lastsessionkey"
    private let lastTimeSessionKey = "lasttimesession"
    private let sessionStartTimeKey = "starttimekey"
    
    private var openAppTime: TimeInterval?
    private var closeAppDateTime: TimeInterval?
    private var sessionActive: Bool = false
    private var isOpenApp: Bool = false
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidEnterBackground() {
        checkSessionToStart()
        
        let currentTime = Date().timeIntervalSince1970
        
        closeAppDateTime = currentTime
        
        userDefaults.set(currentTime, forKey: lastTimeSessionKey)
        
        isOpenApp = false
        
        sessionActive = false
        
        saveSessionTime()
        
        openAppTime = nil
    }
    
    @objc private func applicationWillEnterForeground() {
        let currentTime = Date().timeIntervalSince1970
        userDefaults.set(currentTime, forKey: lastSessionTimeKey)
        handleSessionStart()
    }
    
    private func handleSessionStart() {

        isOpenApp = true
        
        if openAppTime == nil {
            openAppTime = uptime()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            if self.sessionTime() > 0 {
                var count = self.getSessionCount()
                if count == 0 {
                    count = 1
                }
                
                self.addNewSession()
            }
        }
    }
    
    private func checkSessionToStart() {
        if sessionActive {
            return
        }
        
        if sessionTime() > 0 {
            sessionActive = true
        }
    }
    
    private func sessionTime() -> TimeInterval {
        if sessionActive {
            return 0
        }
        

        if let startTime = openAppTime {

            let time = uptime() - startTime - 15
            

            if time > 0 {
                return time
            }
        }
        return 0
    }
    
    private func saveSessionTime() {
        let lifetimeSessionTime = getLifetimeSessionTime()
        userDefaults.set(lifetimeSessionTime, forKey: lifetimeSessionCountKey)
    }
    
    private func getSaveSessionsTime() -> TimeInterval {
        return userDefaults.double(forKey: lifetimeSessionCountKey)
    }
    
    private func addNewSession() {
        let count = getSessionCount() + 1
        userDefaults.set(count, forKey: sessionCountKey)
    }
    
    private func uptime() -> TimeInterval {
        return ProcessInfo.processInfo.systemUptime
    }
    
    
    func startSession() {
        handleSessionStart()
    }
    
    func getSessionCount() -> Int {
        return userDefaults.integer(forKey: sessionCountKey)
    }
    
    func getLifetimeSessionTime() -> TimeInterval {
        return getSaveSessionsTime() + sessionTime()
    }
    
    func getLastInteractionTime() -> TimeInterval? {
        if isOpenApp {
            return Date().timeIntervalSince1970
        } else {
            return closeAppDateTime
        }
    }
    
    func getLastTimeSession() -> TimeInterval? {
        return userDefaults.optionalDouble(forKey: lastTimeSessionKey)
    }
    
    func getLastSessionTime() -> TimeInterval? {
        return userDefaults.optionalDouble(forKey: lastSessionTimeKey)
    }
    
    func getSessionTime() -> TimeInterval {
        if let startTime = openAppTime {
            return uptime() - startTime
        } else {
            return 0
        }
    }
    
    func isSessionActive() -> Bool {
        checkSessionToStart()
        return sessionActive
    }
    
    // MARK: - Last Active Time Components (for push scheduling)
    /// Возвращает час и минуту последнего открытия приложения
    /// Используется для useLastActiveTime в push schedules
    func getLastActiveTimeComponents() -> (hour: Int, minute: Int)? {
        guard let lastSessionTimestamp = getLastSessionTime() else {
            print("⚠️ [SessionService] No last session time available")
            return nil
        }
        
        let date = Date(timeIntervalSince1970: lastSessionTimestamp)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        
        guard let hour = components.hour, let minute = components.minute else {
            return nil
        }
        
        print("⏰ [SessionService] Last active time: \(String(format: "%02d:%02d", hour, minute))")
        return (hour: hour, minute: minute)
    }
} 
