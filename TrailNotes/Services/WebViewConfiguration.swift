import Foundation
import UIKit

// MARK: - WebView Configuration Model
struct WebViewConfiguration: Codable {
    
    // MARK: - Tracking Configuration
    let tracking: TrackingConfig
    
    // MARK: - UI Configuration  
    let ui: UIConfig
    
    // MARK: - Network Configuration
    let network: NetworkConfig
    
    init() {
        // Стандартні налаштування (як зараз, але без інʼєкцій)
        self.tracking = TrackingConfig()
        self.ui = UIConfig()
        self.network = NetworkConfig()
    }
}

// MARK: - Tracking Configuration
struct TrackingConfig: Codable {
    let ajaxEnabled: Bool
    let websocketEnabled: Bool
    let nativeRequestsEnabled: Bool
    let batchIntervalMinutes: Int
    let jsInjectionAjax: String?
    let jsInjectionWebsocket: String?
    
    init(
        ajaxEnabled: Bool = true,  // ✅ ВКЛЮЧЕНО для дебага
        websocketEnabled: Bool = true,  // ✅ ВКЛЮЧЕНО для дебага
        nativeRequestsEnabled: Bool = false,
        batchIntervalMinutes: Int = 1,
        jsInjectionAjax: String? = nil,
        jsInjectionWebsocket: String? = nil
    ) {
        self.ajaxEnabled = ajaxEnabled
        self.websocketEnabled = websocketEnabled
        self.nativeRequestsEnabled = nativeRequestsEnabled
        self.batchIntervalMinutes = batchIntervalMinutes
        self.jsInjectionAjax = jsInjectionAjax
        self.jsInjectionWebsocket = jsInjectionWebsocket
    }
}

// MARK: - UI Configuration
struct UIConfig: Codable {
    let pullToRefreshEnabled: Bool
    let navigationMenuEnabled: Bool
    let navigationMenuStatic: Bool // true = завжди видиме, false = як в Safari
    let progressBarEnabled: Bool
    let webViewBackgroundColor: String? // hex або "auto"
    
    var autoWebViewColor: Bool {
        return webViewBackgroundColor == "auto"
    }
    let menuBackgroundColor: String? // hex або "auto"
    let menuButtonColor: String? // hex або "auto"
    let progressBarColor: String? // hex або "auto"
    let pullRefreshColor: String? // hex або "auto"
    let enabledButtons: [String]
    
    init(
        pullToRefreshEnabled: Bool = true,
        navigationMenuEnabled: Bool = true,
        navigationMenuStatic: Bool = false, // false = динамічна панель як у Safari
        progressBarEnabled: Bool = true,
        webViewBackgroundColor: String? = "auto",
        menuBackgroundColor: String? = nil,
        menuButtonColor: String? = "auto",
        progressBarColor: String? = "auto",
        pullRefreshColor: String? = "auto",
        enabledButtons: [String] = ["back", "forward", "home", "close", "settings"]
    ) {
        self.pullToRefreshEnabled = pullToRefreshEnabled
        self.navigationMenuEnabled = navigationMenuEnabled
        self.navigationMenuStatic = navigationMenuStatic
        self.progressBarEnabled = progressBarEnabled
        self.webViewBackgroundColor = webViewBackgroundColor
        self.menuBackgroundColor = menuBackgroundColor
        self.menuButtonColor = menuButtonColor
        self.progressBarColor = progressBarColor
        self.pullRefreshColor = pullRefreshColor
        self.enabledButtons = enabledButtons
    }
    
    // Custom decoder для підтримки дефолтних значень з сервера
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        pullToRefreshEnabled = try container.decodeIfPresent(Bool.self, forKey: .pullToRefreshEnabled) ?? true
        navigationMenuEnabled = try container.decodeIfPresent(Bool.self, forKey: .navigationMenuEnabled) ?? true
        navigationMenuStatic = try container.decodeIfPresent(Bool.self, forKey: .navigationMenuStatic) ?? false // ⭐ false = динамічна панель
        progressBarEnabled = try container.decodeIfPresent(Bool.self, forKey: .progressBarEnabled) ?? true
        webViewBackgroundColor = try container.decodeIfPresent(String.self, forKey: .webViewBackgroundColor) ?? "auto"
        menuBackgroundColor = try container.decodeIfPresent(String.self, forKey: .menuBackgroundColor)
        menuButtonColor = try container.decodeIfPresent(String.self, forKey: .menuButtonColor) ?? "auto"
        progressBarColor = try container.decodeIfPresent(String.self, forKey: .progressBarColor) ?? "auto"
        pullRefreshColor = try container.decodeIfPresent(String.self, forKey: .pullRefreshColor) ?? "auto"
        enabledButtons = try container.decodeIfPresent([String].self, forKey: .enabledButtons) ?? ["back", "forward", "home", "close", "settings"]
    }
}

// MARK: - Network Configuration
struct NetworkConfig: Codable {
    let serverURL: String?
    let batchSize: Int
    let retryAttempts: Int
    let useragent: String?
    let screenshots_allowed: Bool?
    let debugModeEnabled: Bool? // 🐛 Debug mode flag from server
    
    init(
        serverURL: String? = nil,
        batchSize: Int = 50,
        retryAttempts: Int = 3,
        useragent: String? = nil,
        screenshots_allowed: Bool? = nil,
        debugModeEnabled: Bool? = false // Default: OFF
    ) {
        self.serverURL = serverURL
        self.batchSize = batchSize
        self.retryAttempts = retryAttempts
        self.useragent = useragent
        self.screenshots_allowed = screenshots_allowed
        self.debugModeEnabled = debugModeEnabled
    }
}

// MARK: - Navigation Button Configuration
enum NavigationButton: String, Codable, CaseIterable {
    case back = "chevron.backward"
    case forward = "chevron.forward" 
    case home = "house"
    case reload = "arrow.clockwise"
    case share = "square.and.arrow.up"
    case bookmark = "bookmark"
    case close = "xmark"
    case settings = "gearshape.fill"
    
    var defaultTitle: String {
        switch self {
        case .back: return "Back"
        case .forward: return "Forward"
        case .home: return "Home"
        case .reload: return "Reload"
        case .share: return "Share"
        case .bookmark: return "Bookmark"
        case .close: return "Close"
        case .settings: return "Settings"
        }
    }
}

// MARK: - Color Extensions
extension UIColor {
    convenience init?(hex: String?) {
        guard let hex = hex else { return nil }
        
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        
        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}
