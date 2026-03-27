import UIKit
import AdServices
import WebKit

class MainInfoDictionary: Codable {
    var idfa: String?
    var pushToken: String?
    let deviceModel: String
    let systemVersion: String
    let appVersion: String
    let timestamp: String
    let bundleId: String
    let carrierName: String?
    let carrierMCC: String?
    let isp: String?
    let networkType: String
    let screenDPI: Int
    let screenHeight: Int
    let screenWidth: Int
    let locale: String
    let country: String
    let region: String
    let language: String
    let appleAttributionToken: String?
    let userAgent: String
    let timezone: String
    let timezoneDev: String
    let deviceType: String
    let isEmulator: Bool
    let deviceId: String
    let uuid: String
    let appVersionRaw: String?
    let build: String?
    let cpuType: String
    let device: String
    let installedTime: Int64
    let osAndVersion: String
    let osName: String
    let osVersion: String
    let platform: String
    let localIP: String?
    let proxyIPAddress: String?
    let sdkPlatform: String
    let isVpnActive: Bool
    let isRooted: Bool
    let randomUserId: String?
    let firstOpenTime: Int64?
    let sessionCount: Int
    let lifetimeSessionCount: Int64
    let lastSessionTime: Int64?
    let lastTimeSession: Int64?
    let timeSession: Int64
    
    init(idfa: String? = nil, pushToken: String? = nil) {
        self.idfa = idfa
        self.pushToken = pushToken
        self.deviceModel = UIDevice.current.model
        self.systemVersion = UIDevice.current.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.bundleId = Bundle.main.bundleIdentifier ?? "Unknown"
        self.deviceId = IdentificatorsService.shared.getOrCreateUUID().uuidString.lowercased()
        self.uuid = IdentificatorsService.shared.generateUUID().uuidString.lowercased()
        self.randomUserId = IdentificatorsService.shared.getRandomUserId()
        
        if let firstOpenDate = IdentificatorsService.shared.getFirstOpenDate() {
            self.firstOpenTime = Int64(firstOpenDate.timeIntervalSince1970 * 1000)
        } else {
            self.firstOpenTime = nil
        }
        
        let sessionService = SessionService.shared
        self.sessionCount = sessionService.getSessionCount()
        self.lifetimeSessionCount = Int64(sessionService.getLifetimeSessionTime() * 1000)
        self.timeSession = Int64(sessionService.getSessionTime() * 1000)
        
        if let lastSessionTime = sessionService.getLastSessionTime() {
            self.lastSessionTime = Int64(lastSessionTime * 1000)
        } else {
            self.lastSessionTime = nil
        }
        
        if let lastTimeSession = sessionService.getLastTimeSession() {
            self.lastTimeSession = Int64(lastTimeSession * 1000)
        } else {
            self.lastTimeSession = nil
        }
        
        let networkInfo = AllDeviceInfoService.shared
        self.carrierName = networkInfo.getCarrierName()
        self.carrierMCC = networkInfo.getCarrierMCC()
        self.isp = networkInfo.getISP()
        self.networkType = networkInfo.getNetworkType()
        
        let screen = UIScreen.main
        self.screenDPI = Int(screen.scale)
        self.screenHeight = Int(screen.bounds.height * screen.scale)
        self.screenWidth = Int(screen.bounds.width * screen.scale)
        
        let locale = Locale.current
        self.locale = locale.identifier
        self.country = locale.region?.identifier ?? locale.identifier
        self.region = locale.region?.identifier ?? locale.identifier
        
        if let preferredLanguage = Locale.preferredLanguages.first {
            let languageCode = String(preferredLanguage.prefix(while: { $0 != "-" }))
            self.language = "\(languageCode)_\(self.region)"
        } else {
            self.language = "\(locale.language.languageCode?.identifier ?? locale.identifier)_\(self.region)"
        }

        self.appleAttributionToken = try? AAAttribution.attributionToken()
            

        let webView = WKWebView()
        self.userAgent = webView.value(forKey: "userAgent") as? String ?? "Unknown"
        

        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "XXXXX"
        self.timezone = "UTC\(formatter.string(from: Date()))"
        

        let timeZone = TimeZone.current
        let offset = timeZone.secondsFromGMT()
        let hours = abs(offset) / 3600
        let minutes = (abs(offset) % 3600) / 60
        let sign = offset >= 0 ? "+" : "-"
        self.timezoneDev = String(format: "UTC%@%02d:%02d", sign, hours, minutes)
        

        switch UIDevice.current.userInterfaceIdiom {
        case .unspecified:
            self.deviceType = "smartphone"
        case .phone:
            self.deviceType = "smartphone"
        case .pad:
            self.deviceType = "tablet"
        case .tv:
            self.deviceType = "tv"
        case .carPlay:
            self.deviceType = "car"
        case .mac:
            self.deviceType = "mac"
        case .vision:
            self.deviceType = "vision"
        @unknown default:
            self.deviceType = "smartphone"
        }
        
        #if targetEnvironment(simulator)
        self.isEmulator = true
        #else
        self.isEmulator = false
        #endif

        let systemInfo = AllDeviceInfoService.shared
        self.appVersionRaw = systemInfo.getAppVersionRaw()
        self.build = systemInfo.getBuild()
        self.cpuType = systemInfo.getCPUType()
        self.device = systemInfo.getDevice()
        self.installedTime = systemInfo.getInstallDate()
        self.osAndVersion = systemInfo.getOSAndVersion()
        self.osName = systemInfo.getOSName()
        self.osVersion = systemInfo.getOSVersion()
        self.platform = systemInfo.getPlatform()
        self.localIP = networkInfo.getLocalIP()
        self.proxyIPAddress = networkInfo.getProxyIP()
        self.sdkPlatform = systemInfo.getSDKPlatform()
        self.isVpnActive = networkInfo.isVpnActive()
        self.isRooted = false
    }
}

struct ServerResponse: Codable {
     let url: String?
     let cachingPolicy: String?
     let apns_ban: Bool? // 📩 APNS ban flag from root level
     let webViewConfig: WebViewConfiguration?
}

extension MainInfoDictionary {
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "idfa": idfa as Any,
            "push_token": pushToken as Any,
            "device_model": deviceModel,
            "system_version": systemVersion,
            "app_version": appVersion,
            "timestamp": timestamp,
            "bundle_id": bundleId,
            "carrier_name": carrierName as Any,
            "carrier_mcc": carrierMCC as Any,
            "isp": isp as Any,
            "network_type": networkType,
            "screen_dpi": screenDPI,
            "screen_height": screenHeight,
            "screen_width": screenWidth,
            "locale": locale,
            "country": country,
            "region": region,
            "language": language,
            "apple_attribution_token": appleAttributionToken as Any,
            "user_agent": userAgent,
            "timezone": timezone,
            "timezone_dev": timezoneDev,
            "device_type": deviceType,
            "is_emulator": isEmulator,
            "device_id": deviceId,
            "uuid": uuid,
            "app_version_raw": appVersionRaw as Any,
            "build": build as Any,
            "cpu_type": cpuType,
            "device": device,
            "installed_time": installedTime,
            "os_and_version": osAndVersion,
            "os_name": osName,
            "os_version": osVersion,
            "platform": platform,
            "local_ip": localIP as Any,
            "proxy_ip_address": proxyIPAddress as Any,
            "sdk_platform": sdkPlatform,
            "is_vpn_active": isVpnActive,
            "is_rooted": isRooted,
            "session_count": sessionCount,
            "lifetime_session_count": lifetimeSessionCount,
            "time_session": timeSession
        ]
        
        if let randomUserId = randomUserId {
            dict["random_user_id"] = randomUserId
        }
        
        if let firstOpenTime = firstOpenTime {
            dict["first_open_time"] = firstOpenTime
        }
        
        if let lastSessionTime = lastSessionTime {
            dict["last_session_time"] = lastSessionTime
        }
        
        if let lastTimeSession = lastTimeSession {
            dict["last_time_session"] = lastTimeSession
        }
        
        return dict
    }
} 
