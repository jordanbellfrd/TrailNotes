//
//  SwiftUIWebView.swift
//  NewGrayTemplate
//
//  Created by Roman iMac on 05.09.2025.
//

import SwiftUI
import Combine
import WebKit

import Foundation

extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}

extension UIImage {
    var systemName: String? {
        // Це простий workaround - зберігаємо systemName в accessibilityIdentifier
        return self.accessibilityIdentifier
    }
}

extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255
                    a = 1.0
                    
                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }
        
        return nil
    }
    
    /// Обчислює контрастний колір для кращої читабельності
    func contrastColor() -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Обчислюємо відносну яскравість за формулою WCAG
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        // Якщо фон темний (luminance < 0.5), повертаємо світлий колір
        // Якщо фон світлий, повертаємо темний колір
        if luminance < 0.5 {
            // Темний фон - світлий текст/елементи
            return UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0) // Світло-сірий
        } else {
            // Світлий фон - темний текст/елементи
            return UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // Темно-сірий
        }
    }
    
    /// Обчислює акцентний колір на основі фонового кольору
    func accentColor() -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        if luminance < 0.5 {
            // Темний фон - світлий текст/елементи
            return UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0) // Світло-сірий
        } else {
            // Світлий фон - темний текст/елементи
            return UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0) // Темно-сірий
        }
    }
}

// Предусмотреть момент с перезаписью больше 20 линков
// Предусмотреть момент с открытием popUpWebview


class WebViewHistoryManager: ObservableObject {
    static let shared = WebViewHistoryManager()
    private let userDefaults = SecureUserDefaults.standard
    private let sessionStateKey = "webview_session_state"
    private let popUpStateKey = "webview_popup_session_state"
    
    private init() {}
    
    func saveSessionState(from webView: WKWebView) {
        guard let sessionData = webView.interactionState as? Data else { return }
        userDefaults.set(sessionData, forKey: sessionStateKey)
        userDefaults.synchronize()
    }
    
    func restoreSessionState(to webView: WKWebView, fallbackURL: URL) {
        if let sessionData = userDefaults.data(forKey: sessionStateKey) {
            webView.interactionState = sessionData
        } else {
            // Якщо немає збереженої сесії, завантажуємо початковий URL
            webView.load(URLRequest(url: fallbackURL))
        }
    }
    
    func savePopupSessionState(from webView: WKWebView) {
        guard let sessionData = webView.interactionState as? Data else { return }
        userDefaults.set(sessionData, forKey: popUpStateKey)
        userDefaults.synchronize()
    }
    
    func restorePopupSessionState(to webView: WKWebView, fallbackURL: URL) {
        if let sessionData = userDefaults.data(forKey: popUpStateKey) {
            webView.interactionState = sessionData
        } else {
            // Якщо немає збереженої сесії, завантажуємо початковий URL
            webView.load(URLRequest(url: fallbackURL))
        }
    }
    
    func clearPopUpHistory() {
        userDefaults.removeObject(forKey: popUpStateKey)
        userDefaults.synchronize()
    }
}

struct SwiftUIWebView: UIViewRepresentable {

    let url: URL
    let configuration: WebViewConfiguration
    
    @State private var showingPopup = false
    @StateObject private var historyManager = WebViewHistoryManager.shared
    @State private var loadingProgress: Double = 0.0
    @State private var isLoading: Bool = false
    
    var mainWebView: WKWebView?

    func makeUIView(context: Context) -> UIView {
        let wkConfiguration = WKWebViewConfiguration()
        wkConfiguration.allowsInlineMediaPlayback = true
        
        // Налаштовуємо відстеження згідно конфігурації
        configureTracking(wkConfiguration)

        let webView = WKWebView(frame: .zero, configuration: wkConfiguration)
        
        // Встановлюємо navigation delegate (ВСЕГДА coordinator, tracking внутри!)
        webView.navigationDelegate = context.coordinator
        
        if configuration.tracking.nativeRequestsEnabled {
            logPrint("📱 [WEBVIEW] Native request tracking ENABLED in Coordinator")
        } else {
            logPrint("👤 [WEBVIEW] Coordinator set as navigationDelegate (no native tracking)")
        }
        
        webView.uiDelegate = context.coordinator
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.allowsLinkPreview = false
        webView.scrollView.bounces = true // Увімкнути bounces для pull-to-refresh
        webView.allowsBackForwardNavigationGestures = true
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        // Встановлюємо кастомний User-Agent якщо прийшов з сервера
        if let customUserAgent = SecureUserDefaults.standard.string(forKey: "customUserAgent") {
            webView.customUserAgent = customUserAgent
            logPrint("✅ [WEBVIEW] Using custom User-Agent: \(customUserAgent)")
        } else {
            logPrint("📱 [WEBVIEW] Using default User-Agent")
        }
        
        // Налаштовуємо фоновий колір WebView
        configureWebViewBackgroundColor(webView)
        
        // Налаштовуємо contentInsetAdjustmentBehavior для правильної роботи з панеллю
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        // Додаємо pull-to-refresh тільки якщо увімкнено в конфігурації
        var refreshControl: UIRefreshControl? = nil
        if configuration.ui.pullToRefreshEnabled {
            refreshControl = createPullRefreshControl(coordinator: context.coordinator)
            webView.scrollView.addSubview(refreshControl!)
            webView.scrollView.refreshControl = refreshControl
        }
        
        // Створюємо контейнер
        let containerView = UIView()
        
        // Застосовуємо UI конфігурацію
        applyUIConfiguration(to: containerView)
        
        // Створюємо прогрес-бар тільки якщо увімкнено в конфігурації
        let progressView = createProgressBar()
        progressView.isHidden = !configuration.ui.progressBarEnabled
        
        // Заокруглюємо внутрішні шари прогрес-бару
        DispatchQueue.main.async {
            for subview in progressView.subviews {
                subview.layer.cornerRadius = 1.0
                subview.clipsToBounds = true
            }
        }
        
        // Додаємо WebView та прогрес-бар до контейнера
        webView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(webView)
        containerView.addSubview(progressView)
        
        // Налаштовуємо адаптивну навігацію
//        if configuration.ui.navigationMenuEnabled {
            context.coordinator.adaptiveNavigationManager?.setupNavigation(
                in: containerView,
                webView: webView,
                initialURL: url
            )
//        }
        
        // Базові constraints для прогрес-бару (WebView constraints керуються адаптивним менеджером)
        NSLayoutConstraint.activate([
            // Прогрес-бар прикріплений до низу WebView
            progressView.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2.0)
        ])
        
        // Передаємо дані до координатора
        context.coordinator.webView = webView
        context.coordinator.progressView = progressView
        context.coordinator.refreshControl = refreshControl
        context.coordinator.navigationPanel = nil // Керується адаптивним менеджером
        context.coordinator.navigationButtons = [] // Керується адаптивним менеджером
        context.coordinator.webViewBottomConstraint = nil // Керується адаптивним менеджером
        context.coordinator.url = url
        
        // Відновлюємо збережену сесію або завантажуємо початковий URL
        if(SecureUserDefaults.standard.string(forKey: "cachingPolicy") == "latest"){
            historyManager.restoreSessionState(to: webView, fallbackURL: url)
        } else {
            webView.load(URLRequest(url: url))
        }
        
        // Оновлюємо стан кнопок навігації після ініціалізації
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            context.coordinator.updateNavigationButtons()
        }
        
        // Адаптивна навігація налаштовується автоматично через AdaptiveNavigationManager
        
        // Додаємо KVO для відстеження прогресу
        webView.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "loading", options: .new, context: nil)
        
        // Налаштовуємо спостереження за автоматичним кольором сторінки
        if configuration.ui.webViewBackgroundColor == "auto" {
            context.coordinator.setupAutoBackgroundColorObserver(for: webView)
        }
        
        // Додаємо scroll delegate для відстеження скролу
        webView.scrollView.delegate = context.coordinator
        
        // ✅ TapZone тепер керується AdaptiveNavigationManager - видалено дублікат
        // Старі gesture recognizers для старої navigation panel архітектури
        // Більше не потрібні - все керується через AdaptiveNavigationManager
        
        // Простий layout - панель завжди знизу
        logPrint("📱 Simple navigation - panel always at bottom")
        
        if(!SecureUserDefaults.standard.bool(forKey: "screenshotsAllowed")){
            ScreenShield.shared.protect(view: containerView)
        }
        
        return containerView
    }
    
    // MARK: - Tracking Configuration
    private func configureTracking(_ wkConfiguration: WKWebViewConfiguration) {
        logPrint("\n🚀 [TRACKING CONFIG] Configuring tracking services...")
        logPrint("   AJAX: \(configuration.tracking.ajaxEnabled ? "✅ ENABLED" : "❌ DISABLED")")
        logPrint("   WebSocket: \(configuration.tracking.websocketEnabled ? "✅ ENABLED" : "❌ DISABLED")")
        logPrint("   Native Requests: \(configuration.tracking.nativeRequestsEnabled ? "✅ ENABLED" : "❌ DISABLED")")
        
        // Налаштовуємо DataBatchService з нашою кастомною конфігурацією
        DataBatchService.shared.updateConfiguration(configuration)
        
        // Налаштовуємо AJAX відстеження
        if configuration.tracking.ajaxEnabled {
            AjaxTrackingService.shared.configureWebView(wkConfiguration)
        } else {
            logPrint("⚠️  AJAX tracking is DISABLED - enable it in WebViewConfiguration")
        }
        
        // Налаштовуємо WebSocket відстеження
        if configuration.tracking.websocketEnabled {
            WebSocketTrackingService.shared.configureWebView(wkConfiguration)
        } else {
            logPrint("⚠️  WebSocket tracking is DISABLED - enable it in WebViewConfiguration")
        }
        
        // Запускаємо пакетну передачу якщо є сервер
        if configuration.network.serverURL != nil {
            DataBatchService.shared.startBatching()
        }
        
        logPrint("🚀 [TRACKING CONFIG] Configuration complete!\n")
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    // MARK: - UI Configuration Methods
    
    private func configureWebViewBackgroundColor(_ webView: WKWebView) {
        if configuration.ui.webViewBackgroundColor == "auto" {
            // Автоматичний колір сторінки - дозволяємо WebView автоматично визначати колір
            if #available(iOS 15.0, *) {
                // underPageBackgroundColor автоматично отримає колір з HTML/body
                // Не встановлюємо його явно, щоб дозволити автоматичне визначення
                webView.backgroundColor = .clear
                logPrint("🎨 WebView background set to auto (underPageBackgroundColor will derive from page)")
            } else {
                webView.backgroundColor = .systemBackground
                logPrint("🎨 WebView background set to systemBackground (iOS < 15)")
            }
        } else if let bgColor = configuration.ui.webViewBackgroundColor {
            // Використовуємо hex колір з конфігурації
            let color = UIColor(hex: bgColor)
            webView.backgroundColor = color
            if #available(iOS 15.0, *) {
                webView.underPageBackgroundColor = color
            }
            logPrint("🎨 WebView background set to: \(bgColor)")
        }
    }
    
    private func applyUIConfiguration(to containerView: UIView) {
        // Застосовуємо фоновий колір для safe area зон (чорні полоски)
        if configuration.ui.webViewBackgroundColor == "auto" {
            // Автоматичний колір - прозорий, щоб показувати колір сторінки
            if #available(iOS 15.0, *) {
                containerView.backgroundColor = .clear
                logPrint("🎨 Container background set to clear (auto mode)")
            } else {
                containerView.backgroundColor = .systemBackground
                logPrint("🎨 Container background set to systemBackground (iOS < 15)")
            }
        } else if let bgColor = configuration.ui.webViewBackgroundColor {
            // Використовуємо hex колір з конфігурації
            containerView.backgroundColor = UIColor(hex: bgColor)
            logPrint("🎨 Container background set to: \(bgColor)")
        }
    }
    
    private func createProgressBar() -> UIProgressView {
        let progressView = UIProgressView(progressViewStyle: .bar)
        
        // Застосовуємо колір прогрес-бару з конфігурації
        if configuration.ui.progressBarColor == "auto" {
            // Автоматичний колір буде встановлений пізніше через NotificationCenter
            progressView.progressTintColor = .systemBlue // Тимчасовий колір
        } else if let progressColor = configuration.ui.progressBarColor {
            progressView.progressTintColor = UIColor(hex: progressColor)
        } else {
            progressView.progressTintColor = .systemBlue
        }
        
        progressView.trackTintColor = .clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.alpha = 0.0
        progressView.layer.cornerRadius = 1.0
        progressView.clipsToBounds = true
        
        return progressView
    }
    
    private func createPullRefreshControl(coordinator: Coordinator) -> UIRefreshControl {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(coordinator, action: #selector(coordinator.refreshWebView), for: .valueChanged)
        
        // Застосовуємо колір pull-to-refresh з конфігурації
        if configuration.ui.pullRefreshColor == "auto" {
            // Автоматичний колір буде встановлений пізніше через NotificationCenter
            refreshControl.tintColor = .systemBlue // Тимчасовий колір
        } else if let refreshColor = configuration.ui.pullRefreshColor {
            refreshControl.tintColor = UIColor(hex: refreshColor)
        } else {
            refreshControl.tintColor = .systemBlue
        }
        
        return refreshControl
    }
    
    private func createNavigationPanel() -> UIView {
        let navigationPanel = UIView()
        
        // Застосовуємо фоновий колір меню з конфігурації
        if let menuBgColor = configuration.ui.menuBackgroundColor {
            navigationPanel.backgroundColor = UIColor(hex: menuBgColor)?.withAlphaComponent(0.95)
        } else {
            // Використовуємо сучасний зелений колір як на скріншоті
            navigationPanel.backgroundColor = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.95)
        }
        
        // Покращена тінь
        navigationPanel.layer.shadowColor = UIColor.black.cgColor
        navigationPanel.layer.shadowOffset = CGSize(width: 0, height: -2)
        navigationPanel.layer.shadowRadius = 8
        navigationPanel.layer.shadowOpacity = 0.1
        
        navigationPanel.translatesAutoresizingMaskIntoConstraints = false
        navigationPanel.alpha = 0.0
        
        return navigationPanel
    }
    
    private func createNavigationButtons(coordinator: Coordinator) -> [UIButton] {
        var buttons: [UIButton] = []
        
        // Отримуємо колір кнопок з конфігурації
        let buttonColor: UIColor
        if configuration.ui.menuButtonColor == "auto" {
            // Автоматичний колір буде встановлений пізніше через NotificationCenter
            buttonColor = .label // Тимчасовий колір
        } else if let menuButtonColor = configuration.ui.menuButtonColor {
            buttonColor = UIColor(hex: menuButtonColor) ?? .label
        } else {
            buttonColor = .label
        }
        
        // Створюємо кнопки згідно конфігурації
        logPrint("🔘 Creating buttons for: \(configuration.ui.enabledButtons)")
        for buttonTypeString in configuration.ui.enabledButtons {
            let systemImageName = getSystemImageName(for: buttonTypeString)
            logPrint("🔘 Button '\(buttonTypeString)' -> system image: '\(systemImageName)'")
            if let buttonType = NavigationButton(rawValue: systemImageName) {
                logPrint("🔘 Successfully created NavigationButton: \(buttonType)")
                let button = createButton(for: buttonType, color: buttonColor, coordinator: coordinator)
                buttons.append(button)
            } else {
                logPrint("❌ Failed to create NavigationButton for rawValue: '\(systemImageName)'")
            }
        }
        
        return buttons
    }
    
    private func createButton(for buttonType: NavigationButton, color: UIColor, coordinator: Coordinator) -> UIButton {
        let button = UIButton(type: .system)
        
        // Створюємо сучасний дизайн кнопки
        let image = UIImage(systemName: buttonType.rawValue, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
        image?.accessibilityIdentifier = buttonType.rawValue // Зберігаємо systemName
        button.setImage(image, for: .normal)
        button.tintColor = .white // Білі іконки на зеленому фоні
        
        // Додаємо фоновий круг для кнопки
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 22 // Для кнопки 44x44
        
        // Додаємо ефект натискання
        button.addTarget(coordinator, action: #selector(coordinator.buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(coordinator, action: #selector(coordinator.buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Додаємо дії для кнопок
        switch buttonType.rawValue {
        case "chevron.backward":
            button.addTarget(coordinator, action: #selector(coordinator.goBack), for: .touchUpInside)
        case "chevron.forward":
            button.addTarget(coordinator, action: #selector(coordinator.goForward), for: .touchUpInside)
        case "house":
            button.addTarget(coordinator, action: #selector(coordinator.goHome), for: .touchUpInside)
        case "arrow.clockwise":
            button.addTarget(coordinator, action: #selector(coordinator.refreshWebView), for: .touchUpInside)
        case "square.and.arrow.up":
            button.addTarget(coordinator, action: #selector(coordinator.shareCurrentPage), for: .touchUpInside)
        case "bookmark":
            button.addTarget(coordinator, action: #selector(coordinator.bookmarkCurrentPage), for: .touchUpInside)
        case "xmark":
            button.addTarget(coordinator, action: #selector(coordinator.hideNavigationPanel), for: .touchUpInside)
        default:
            break
        }
        
        return button
    }
    
    
    private func getSystemImageName(for buttonName: String) -> String {
        switch buttonName.lowercased() {
        case "back":
            return "chevron.backward"
        case "forward":
            return "chevron.forward"
        case "home":
            return "house"
        case "reload":
            return "arrow.clockwise"
        case "share":
            return "square.and.arrow.up"
        case "bookmark":
            return "bookmark"
        case "close":
            return "xmark"
        default:
            return "questionmark"
        }
    }
    
    // ВИДАЛЕНО: Старий метод setupNavigationButtonsConstraints
    // Замінено на нову архітектуру з constraint management в Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: SwiftUIWebView
        var popupContainerView: UIView?
        var poppWView: WKWebView?
        weak var webView: WKWebView?
        weak var progressView: UIProgressView?
        weak var refreshControl: UIRefreshControl?
        weak var navigationPanel: UIView?
        var navigationButtons: [UIButton] = []
        var adaptiveNavigationManager: AdaptiveNavigationManager?
        weak var tapZone: UIView?
        var url: URL?
        
        var firstOpenView : Bool = true
        private var navigationPanelBottomConstraint: NSLayoutConstraint?
         var webViewBottomConstraint: NSLayoutConstraint?
        private var hideNavigationTimer: Timer?
        var isNavigationPanelVisible = false
        private var lastScrollOffset: CGFloat = 0
        private var lastScrollTime: CFTimeInterval = 0
        private var scrollVelocity: CGFloat = 0
         var panGestureRecognizer: UIPanGestureRecognizer?
        var panelDragProgress: CGFloat = 0 // 0.0 = hidden, 1.0 = fully visible
        private var initialPanelState: Bool = false
        private var panStartLocation: CGPoint = .zero
        private var lastPanTranslation: CGFloat = 0

        init(parent: SwiftUIWebView) {
            self.parent = parent
            self.lastScrollTime = CACurrentMediaTime()
            
            // Для статичного меню встановлюємо початкову видимість
            if parent.configuration.ui.navigationMenuStatic {
                self.isNavigationPanelVisible = true
                self.panelDragProgress = 1.0
                logPrint("🔒 Static navigation menu enabled - panel will be always visible")
            }
            
            super.init()
            
            // Ініціалізуємо адаптивний навігаційний менеджер
            self.adaptiveNavigationManager = AdaptiveNavigationManager(configuration: parent.configuration)
            
            // Зберігаємо історію при закритті апки
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(saveHistoryOnBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(saveHistoryOnTerminate),
                name: UIApplication.willTerminateNotification,
                object: nil
            )
            
            // Видалено: спостереження за орієнтацією - панель завжди знизу
            
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            // Видаляємо KVO observers
            webView?.removeObserver(self, forKeyPath: "estimatedProgress")
            webView?.removeObserver(self, forKeyPath: "loading")
            // Очищуємо таймер
            hideNavigationTimer?.invalidate()
        }
        
        @objc private func saveHistoryOnBackground() {
            guard let webView = webView else { return }
            WebViewHistoryManager.shared.saveSessionState(from: webView)
        }
        
        @objc private func saveHistoryOnTerminate() {
            guard let webView = webView else { return }
            WebViewHistoryManager.shared.saveSessionState(from: webView)
        }
        
        @objc func refreshWebView() {
            guard let webView = webView else { return }
            webView.reload()
            
            // Оновлюємо стан кнопок після перезавантаження
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateNavigationButtons()
            }
        }
        
        @objc func goBack() {
            guard let webView = webView else { return }
            if webView.canGoBack {
                webView.goBack()
                
                // Оновлюємо стан кнопок одразу після навігації
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.updateNavigationButtons()
                }
                
                // Для статичного меню не ховаємо панель
                if !parent.configuration.ui.navigationMenuStatic {
                    hideNavigationPanelAnimated()
                }
            }
        }
        
        @objc func goForward() {
            guard let webView = webView else { return }
            if webView.canGoForward {
                webView.goForward()
                
                // Оновлюємо стан кнопок одразу після навігації
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.updateNavigationButtons()
                }
                
                // Для статичного меню не ховаємо панель
                if !parent.configuration.ui.navigationMenuStatic {
                    hideNavigationPanelAnimated()
                }
            }
        }
        
        @objc func goHome() {
            guard let webView = webView, let url = url else { return }
            webView.load(URLRequest(url: url))
            
            // Оновлюємо стан кнопок одразу після навігації
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateNavigationButtons()
            }
            
            // Для статичного меню не ховаємо панель
            if !parent.configuration.ui.navigationMenuStatic {
                hideNavigationPanelAnimated()
            }
        }
        
        @objc func shareCurrentPage() {
            guard let webView = webView,
                  let url = webView.url else { return }
            
            let activityViewController = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                var presentingViewController = rootViewController
                while let presented = presentingViewController.presentedViewController {
                    presentingViewController = presented
                }
                
                presentingViewController.present(activityViewController, animated: true)
            }
            
            // Для статичного меню не ховаємо панель
            if !parent.configuration.ui.navigationMenuStatic {
                hideNavigationPanelAnimated()
            }
        }
        
        @objc func bookmarkCurrentPage() {
            // Тут можна додати логіку збереження закладок
            logPrint("📖 Bookmark current page")
            
            // Для статичного меню не ховаємо панель
            if !parent.configuration.ui.navigationMenuStatic {
                hideNavigationPanelAnimated()
            }
        }
        
        @objc func buttonTouchDown(_ button: UIButton) {
            UIView.animate(withDuration: 0.1) {
                button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                button.backgroundColor = UIColor.white.withAlphaComponent(0.3)
            }
        }
        
        @objc func buttonTouchUp(_ button: UIButton) {
            UIView.animate(withDuration: 0.1) {
                button.transform = CGAffineTransform.identity
                button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            }
        }
        
        @objc func handleBottomTap() {
            if isNavigationPanelVisible {
                hideNavigationPanel()
            } else {
                showNavigationPanel()
            }
        }
        
        // MARK: - Pan Gesture Handling
        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            guard let containerView = gesture.view else { return }
            
            let translation = gesture.translation(in: containerView)
            let velocity = gesture.velocity(in: containerView)
            let location = gesture.location(in: containerView)
            
            switch gesture.state {
            case .began:
                handlePanBegan(location: location)
            case .changed:
                handlePanChanged(translation: translation)
            case .ended, .cancelled:
                handlePanEnded(translation: translation, velocity: velocity)
            default:
                break
            }
        }
        
        private func handlePanBegan(location: CGPoint) {
            guard let containerView = navigationPanel?.superview else { return }
            
            panStartLocation = location
            initialPanelState = isNavigationPanelVisible
            lastPanTranslation = 0
            resetHideTimer()
            
            // Визначаємо чи жест починається в нижній частині екрану
            let containerHeight = containerView.bounds.height
            let bottomThreshold = containerHeight * 0.7 // Нижні 30% екрану
            
            // Дозволяємо жест тільки якщо:
            // 1. Панель вже видима (можна тягти звідки завгодно)
            // 2. Жест починається в нижній частині екрану
            if !isNavigationPanelVisible && location.y < bottomThreshold {
                return
            }
        }
        
        private func handlePanChanged(translation: CGPoint) {
            let deltaY = translation.y - lastPanTranslation
            lastPanTranslation = translation.y
            
            // Визначаємо напрямок жесту
            let isSwipingUp = deltaY < 0
            let isSwipingDown = deltaY > 0
            
            // Обчислюємо прогрес на основі переміщення
            let panelHeight: CGFloat = 50
            var progress = panelDragProgress
            
            if isSwipingDown && !initialPanelState {
                // Свайп вниз для показу панелі
                progress = min(1.0, progress + abs(deltaY) / panelHeight)
            } else if isSwipingUp && initialPanelState {
                // Свайп вгору для приховування панелі
                progress = max(0.0, progress - abs(deltaY) / panelHeight)
            }
            
            updatePanelProgressSmooth(progress)
        }
        
        private func handlePanEnded(translation: CGPoint, velocity: CGPoint) {
            let velocityThreshold: CGFloat = 300
            let progressThreshold: CGFloat = 0.5
            
            // Визначаємо фінальний стан
            let shouldShow: Bool
            
            if abs(velocity.y) > velocityThreshold {
                // Швидкий жест - рішення на основі напрямку
                shouldShow = velocity.y > 0 // Вниз = показати
            } else {
                // Повільний жест - рішення на основі прогресу
                shouldShow = panelDragProgress > progressThreshold
            }
            
            // Анімуємо до фінального стану
            if shouldShow && !isNavigationPanelVisible {
                showNavigationPanelAnimated()
                scheduleHideNavigation()
            } else if !shouldShow && isNavigationPanelVisible {
                hideNavigationPanelAnimated()
            } else if shouldShow && isNavigationPanelVisible {
                // Панель вже видима, просто скидаємо таймер
                scheduleHideNavigation()
            }
        }
        
        // MARK: - UIGestureRecognizerDelegate
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Дозволяємо одночасну роботу з scroll gesture
            return true
        }
        
        // MARK: - KVO
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = webView, let progressView = progressView else { return }
            
            if keyPath == "estimatedProgress" {
                let progress = Float(webView.estimatedProgress)
                
                DispatchQueue.main.async {
                    progressView.setProgress(progress, animated: true)
                    
                    // Переконуємося, що внутрішні шари залишаються заокругленими
                    for subview in progressView.subviews {
                        subview.layer.cornerRadius = 1.0
                        subview.clipsToBounds = true
                    }
                }
            } else if keyPath == "loading" {
                let isLoading = webView.isLoading
                
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.3) {
                        progressView.alpha = isLoading ? 1.0 : 0.0
                    }
                    
                    if !isLoading {
                        // Коли завантаження завершено, скидаємо прогрес через невелику затримку
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            progressView.setProgress(0.0, animated: false)
                        }
                    }
                }
            } else if keyPath == "underPageBackgroundColor",
                      parent.configuration.ui.webViewBackgroundColor == "auto" {
                
                if #available(iOS 15.0, *),
                   let webView = object as? WKWebView {
                    let pageColor = webView.underPageBackgroundColor
                    logPrint("🎨 Page background color changed to: \(pageColor?.description ?? "nil")")
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.applyPageBackgroundColor(pageColor)
                    }
                }
            } else {
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
        
        // MARK: - UIScrollViewDelegate
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Передаємо події скролу до адаптивного менеджера навігації
            adaptiveNavigationManager?.scrollViewDidScroll(scrollView)
            
            // Для старого navigation panel
            // Для статичного меню не обробляємо скрол
            if parent.configuration.ui.navigationMenuStatic {
                return
            }
            
            let currentTime = CACurrentMediaTime()
            let currentOffset = scrollView.contentOffset.y
            
            // Обчислюємо швидкість скролу
            let timeDelta = currentTime - lastScrollTime
            if timeDelta > 0.016 { // ~60fps
                let offsetDelta = currentOffset - lastScrollOffset
                scrollVelocity = offsetDelta / CGFloat(timeDelta)
                lastScrollTime = currentTime
                lastScrollOffset = currentOffset
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            // Передаємо події скролу до адаптивного менеджера навігації
            adaptiveNavigationManager?.scrollViewWillBeginDragging(scrollView)
            
            // Для старого navigation panel
            // Для статичного меню не обробляємо скрол
            if parent.configuration.ui.navigationMenuStatic {
                return
            }
            
            resetHideTimer()
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            // Передаємо події скролу до адаптивного менеджера навігації
            adaptiveNavigationManager?.scrollViewWillEndDragging(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
            
            // Для старого navigation panel
            // Для статичного меню не обробляємо скрол
            if parent.configuration.ui.navigationMenuStatic {
                return
            }
            
            // Використовуємо офіційний velocity від системи
            let velocityY = velocity.y
            let currentOffset = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let scrollViewHeight = scrollView.frame.height
            let maxOffset = contentHeight - scrollViewHeight
            
            // Safari-подібна логіка
            let velocityThreshold: CGFloat = 0.5
            let isNearBottom = currentOffset > maxOffset - 50
            
            if velocityY > velocityThreshold {
                // Швидкий свайп вниз - приховуємо панель
                if isNavigationPanelVisible {
                    hideNavigationPanelAnimated()
                }
            } else if velocityY < -velocityThreshold {
                // Швидкий свайп вгору - показуємо панель
                if !isNavigationPanelVisible {
                    showNavigationPanelAnimated()
                    scheduleHideNavigation()
                }
            } else if isNearBottom && !isNavigationPanelVisible {
                // Біля низу сторінки - показуємо панель
                showNavigationPanelAnimated()
                scheduleHideNavigation()
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            // Передаємо події скролу до адаптивного менеджера навігації
            adaptiveNavigationManager?.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
            
            // Для старого navigation panel
            // Для статичного меню не обробляємо скрол
            if parent.configuration.ui.navigationMenuStatic {
                return
            }
            
            if !decelerate && isNavigationPanelVisible {
                scheduleHideNavigation()
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            // Передаємо події скролу до адаптивного менеджера навігації
            adaptiveNavigationManager?.scrollViewDidEndDecelerating(scrollView)
            
            // Для старого navigation panel
            // Для статичного меню не обробляємо скрол
            if parent.configuration.ui.navigationMenuStatic {
                return
            }
            
            if isNavigationPanelVisible {
                scheduleHideNavigation()
            }
        }
        
        private func updatePanelProgressSmooth(_ progress: CGFloat) {
            guard let navigationPanel = navigationPanel else { return }
            
            panelDragProgress = progress
            let navigationHeight: CGFloat = 50
            
            // Плавно оновлюємо позицію панелі (слідує за пальцем)
            let yOffset = navigationHeight * (1.0 - progress)
            navigationPanel.transform = CGAffineTransform(translationX: 0, y: yOffset)
            navigationPanel.alpha = progress
            
            // Оновлюємо стан видимості панелі
            if progress > 0.1 && !isNavigationPanelVisible {
                isNavigationPanelVisible = true
                updateWebViewConstraints(forPanelVisible: true)
            } else if progress < 0.1 && isNavigationPanelVisible {
                isNavigationPanelVisible = false
                updateWebViewConstraints(forPanelVisible: false)
            }
        }
        
        func updateWebViewConstraints(forPanelVisible visible: Bool) {
            guard let webView = webView,
                  let webViewBottomConstraint = webViewBottomConstraint,
                  let navigationPanel = navigationPanel else { return }
            
            webViewBottomConstraint.isActive = false
            
            let newConstraint: NSLayoutConstraint
            if visible {
                newConstraint = webView.bottomAnchor.constraint(equalTo: navigationPanel.topAnchor)
            } else {
                if let progressView = progressView {
                    newConstraint = webView.bottomAnchor.constraint(equalTo: progressView.topAnchor)
                } else {
                    newConstraint = webView.bottomAnchor.constraint(equalTo: webView.superview!.safeAreaLayoutGuide.bottomAnchor, constant: -2.0)
                }
            }
            
            newConstraint.isActive = true
            self.webViewBottomConstraint = newConstraint
        }
        
        private func updatePanelProgress(_ progress: CGFloat) {
            guard let navigationPanel = navigationPanel,
                  let webView = webView,
                  let webViewBottomConstraint = webViewBottomConstraint else { return }
            
            panelDragProgress = progress
            let navigationHeight: CGFloat = 50
            
            // Оновлюємо позицію панелі без анімації (слідує за пальцем)
            let yOffset = navigationHeight * (1.0 - progress)
            navigationPanel.transform = CGAffineTransform(translationX: 0, y: yOffset)
            navigationPanel.alpha = progress
            
            // Поступово змінюємо constraint WebView
            if progress > 0.1 && !isNavigationPanelVisible {
                webViewBottomConstraint.isActive = false
                let newConstraint = webView.bottomAnchor.constraint(equalTo: navigationPanel.topAnchor)
                newConstraint.isActive = true
                self.webViewBottomConstraint = newConstraint
                isNavigationPanelVisible = true
            } else if progress < 0.1 && isNavigationPanelVisible {
                webViewBottomConstraint.isActive = false
                if let progressView = progressView {
                    let newConstraint = webView.bottomAnchor.constraint(equalTo: progressView.topAnchor)
                    newConstraint.isActive = true
                    self.webViewBottomConstraint = newConstraint
                }
                isNavigationPanelVisible = false
            }
        }
        
        private func showNavigationPanelAnimated() {
            guard let navigationPanel = navigationPanel,
                  !isNavigationPanelVisible else { return }
            
            isNavigationPanelVisible = true
            panelDragProgress = 1.0
            
            // Оновлюємо constraints
            updateWebViewConstraints(forPanelVisible: true)
            
            // Safari-подібна анімація
            let duration: TimeInterval = 0.35
            let damping: CGFloat = 0.85
            let velocity: CGFloat = 0.8
            
            UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: [.curveEaseOut, .allowUserInteraction]) {
                navigationPanel.alpha = 1.0
                navigationPanel.transform = CGAffineTransform.identity
                navigationPanel.superview?.layoutIfNeeded()
            }
        }
        
        @objc private func hideNavigationPanelAnimated() {
            guard let navigationPanel = navigationPanel,
                  isNavigationPanelVisible else { return }
            
            isNavigationPanelVisible = false
            panelDragProgress = 0.0
            resetHideTimer()
            
            let navigationHeight: CGFloat = 50
            
            // Оновлюємо constraints
            updateWebViewConstraints(forPanelVisible: false)
            
            // Safari-подібна анімація приховування
            let duration: TimeInterval = 0.25
            
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn, .allowUserInteraction]) {
                navigationPanel.alpha = 0.0
                navigationPanel.transform = CGAffineTransform(translationX: 0, y: navigationHeight)
                navigationPanel.superview?.layoutIfNeeded()
            }
        }
        
        private func showNavigationPanel() {
            showNavigationPanelAnimated()
        }
        
        @objc func hideNavigationPanel() {
            hideNavigationPanelAnimated()
        }
        
        // Видалено: orientationDidChange - панель завжди знизу
        
        // Видалено: складна логіка орієнтації - панель завжди знизу
        
        // Простий layout - тільки bottom constraints
        func setupSimpleNavigationConstraints(panel: UIView, containerView: UIView) {
            // Панель завжди знизу з покращеними відступами
            NSLayoutConstraint.activate([
                panel.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                panel.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                panel.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -8),
                panel.heightAnchor.constraint(equalToConstant: 60) // Збільшуємо висоту для кращого вигляду
            ])
            
            // Створюємо кнопки
            setupButtonConstraints(in: panel)
        }
        
        private var buttonStackView: UIStackView?
        
        private func setupButtonConstraints(in panel: UIView) {
            // Створюємо сучасний горизонтальний StackView
            buttonStackView = UIStackView(arrangedSubviews: navigationButtons)
            buttonStackView?.axis = .horizontal
            buttonStackView?.distribution = .equalSpacing
            buttonStackView?.alignment = .center
            buttonStackView?.spacing = 0 // Використовуємо equalSpacing замість фіксованого spacing
            buttonStackView?.translatesAutoresizingMaskIntoConstraints = false
            
            // Встановлюємо розміри для кнопок ПЕРЕД додаванням до StackView
            for button in navigationButtons {
                NSLayoutConstraint.activate([
                    button.widthAnchor.constraint(equalToConstant: 44),
                    button.heightAnchor.constraint(equalToConstant: 44)
                ])
            }
            
            // Додаємо StackView до панелі
            if let stackView = buttonStackView {
                panel.addSubview(stackView)
                
                // Центруємо StackView в панелі з кращими відступами
                NSLayoutConstraint.activate([
                    stackView.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
                    stackView.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
                    stackView.leadingAnchor.constraint(greaterThanOrEqualTo: panel.leadingAnchor, constant: 24),
                    stackView.trailingAnchor.constraint(lessThanOrEqualTo: panel.trailingAnchor, constant: -24),
                    stackView.heightAnchor.constraint(equalToConstant: 44)
                ])
            }
            
            logPrint("📱 Modern navigation buttons setup completed with \(navigationButtons.count) buttons")
        }
        
        // ВИДАЛЕНО: Старий метод updateNavigationPanelLayout(isLandscape:in:) 
        // Замінено на правильну архітектуру з constraint management
        
        private func resetHideTimer() {
            hideNavigationTimer?.invalidate()
            hideNavigationTimer = nil
        }
        
        private func scheduleHideNavigation() {
            guard isNavigationPanelVisible else { return }
            
            // Якщо меню статичне, не ховаємо його
            if parent.configuration.ui.navigationMenuStatic {
                logPrint("🔒 Navigation menu is static, not scheduling hide")
                return
            }
            
            resetHideTimer()
            // Safari приховує панель через 3 секунди неактивності
            hideNavigationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.hideNavigationPanelAnimated()
            }
        }
        
        func updateNavigationButtons() {
            // Оновлюємо стан через адаптивний менеджер
            adaptiveNavigationManager?.updateNavigationState()
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {

            guard navigationAction.targetFrame == nil || !(navigationAction.targetFrame?.isMainFrame ?? true) else {
                return nil
            }

            let popupWebView = WKWebView(frame: .zero, configuration: configuration)
            popupWebView.navigationDelegate = self
            popupWebView.uiDelegate = self
            popupWebView.translatesAutoresizingMaskIntoConstraints = false

            if let url = navigationAction.request.url {
                popupWebView.load(URLRequest(url: url))
            }

            presentPopupWebView(popupWebView, in: webView)
            poppWView = popupWebView
            return popupWebView
        }

        private func presentPopupWebView(_ popupWebView: WKWebView, in mainWebView: WKWebView) {
            guard let containerView = mainWebView.superview else { return }
            
            let overlayView = UIView(frame: UIScreen.main.bounds)
            overlayView.backgroundColor = .black
            overlayView.alpha = 0.0
            overlayView.translatesAutoresizingMaskIntoConstraints = false

            containerView.addSubview(overlayView)
            overlayView.addSubview(popupWebView)

            let closeButton = UIButton(type: .system)
            closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
            closeButton.tintColor = .white
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            closeButton.addTarget(self, action: #selector(closePopup), for: .touchUpInside)
            
            overlayView.addSubview(closeButton)
            
            NSLayoutConstraint.activate([
                overlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
                overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                overlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                
                popupWebView.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 44),
                popupWebView.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor),
                popupWebView.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
                popupWebView.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
                
                closeButton.trailingAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.trailingAnchor, constant: -15),
                closeButton.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 10)
            ])
            
            UIView.animate(withDuration: 0.2) {
                overlayView.alpha = 1.0
            }
            self.popupContainerView = overlayView
        }
        
        @objc private func closePopup() {
            UIView.animate(withDuration: 0.2, animations: {
                self.popupContainerView?.alpha = 0
            }) { _ in
                self.popupContainerView?.removeFromSuperview()
                self.popupContainerView = nil
                WebViewHistoryManager.shared.clearPopUpHistory()
            }
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // Оновлюємо стан кнопок навігації одразу при початку навігації
            // Це важливо для свайп-жестів та програмної навігації
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateNavigationButtons()
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url?.absoluteString else { return }
            
            // Зупиняємо refresh control після завантаження
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
            
            // Оновлюємо стан кнопок навігації
            updateNavigationButtons()
            
            if(webView == self.webView){
                WebViewHistoryManager.shared.saveSessionState(from: webView)
                
                if(firstOpenView){
                    firstOpenView = false
                    if(SecureUserDefaults.standard.string(forKey: "cachingPolicy") == "latest"){
                        if(SecureUserDefaults.standard.data(forKey: "webview_popup_session_state") != nil){
                            self.openPopUp()
                        }
                    }
                }
            } else {
                WebViewHistoryManager.shared.savePopupSessionState(from: webView)
            }
          
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Зупиняємо refresh control у випадку помилки
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
            
            // Оновлюємо стан кнопок навігації
            updateNavigationButtons()
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // Зупиняємо refresh control у випадку помилки provisional navigation
            DispatchQueue.main.async {
                self.refreshControl?.endRefreshing()
            }
            
            // Оновлюємо стан кнопок навігації
            updateNavigationButtons()
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let request = navigationAction.request
            let urlString = request.url?.absoluteString ?? "unknown"
            
            // 📊 Native Request Tracking (если включен на сервере)
            if parent.configuration.tracking.nativeRequestsEnabled {
                // Фільтруємо тільки валідні URL
                if !urlString.hasPrefix("about:") && !urlString.hasPrefix("data:") && !urlString.hasPrefix("blob:") {
                    let nativeData = NativeRequestData(
                        method: request.httpMethod ?? "GET",
                        url: urlString,
                        body: request.httpBody?.base64EncodedString(),
                        navigationType: navigationTypeString(navigationAction.navigationType)
                    )
                    
                    DataBatchService.shared.addNativeRequest(nativeData)
                    logPrint("📱 [NATIVE TRACKING] \(nativeData.navigationType): \(urlString)")
                }
            }
            
            // Существующая логика обработки (НЕ ЛОМАЕТСЯ!)
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            
            // Обробка data URL для зображень
            if url.scheme == "data" {
                let urlString = url.absoluteString
                if urlString.hasPrefix("data:image/") {
                    handleDataImageURL(urlString, in: webView)
                }
                decisionHandler(.cancel)
                return
            }
            
            // Дозволяємо blob URL - WebView обробить їх природним чином
            if url.scheme == "blob" {
                decisionHandler(.allow)
                return
            }
            
            if !["http", "https", "about"].contains(url.scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
        
        // MARK: - Helper для типа навигации
        private func navigationTypeString(_ type: WKNavigationType) -> String {
            switch type {
            case .linkActivated:
                return "link"
            case .formSubmitted:
                return "form"
            case .backForward:
                return "navigation"
            case .reload:
                return "reload"
            case .formResubmitted:
                return "form_resubmit"
            case .other:
                return "other"
            @unknown default:
                return "unknown"
            }
        }
        
        private func handleDataImageURL(_ dataURL: String, in webView: WKWebView) {
            guard let image = ImageDataService.shared.imageFromDataURL(dataURL) else {
                logPrint("Failed to convert data URL to image")
                return
            }
            
            // Показуємо тільки Share Sheet
            DispatchQueue.main.async {
                ImageDataService.shared.shareImage(image, from: webView)
            }
        }
        
        
        
        public func openPopUp(){
            let configuration = WKWebViewConfiguration()
            configuration.allowsInlineMediaPlayback = true
            
            let popupWebView = WKWebView(frame: .zero, configuration: configuration)
            popupWebView.navigationDelegate = self
            popupWebView.uiDelegate = self
            popupWebView.translatesAutoresizingMaskIntoConstraints = false
            popupWebView.allowsBackForwardNavigationGestures = true

            WebViewHistoryManager.shared.restorePopupSessionState(to: popupWebView, fallbackURL: url!)

            presentPopupWebView(popupWebView, in: webView!)
            poppWView = popupWebView
            
        }
        
        // MARK: - Auto Background Color Observer
        
        func setupAutoBackgroundColorObserver(for webView: WKWebView) {
            // Спостерігаємо за зміною underPageBackgroundColor
            if #available(iOS 15.0, *) {
                webView.addObserver(self, forKeyPath: "underPageBackgroundColor", options: [.new], context: nil)
            }
        }
        
        
        private func applyPageBackgroundColor(_ color: UIColor?) {
            guard let color = color,
                  let containerView = webView?.superview else { return }
            
            containerView.backgroundColor = color
            logPrint("🎨 Applied page background color to container")
            
            // Оновлюємо кольори UI елементів якщо вони в auto режимі
            updateAutoColors(basedOn: color)
            
            // Повідомляємо ContentView про зміну кольору
            NotificationCenter.default.post(
                name: .pageBackgroundColorChanged,
                object: color
            )
        }
        
        private func updateAutoColors(basedOn backgroundColor: UIColor) {
            let contrastColor = backgroundColor.contrastColor()
            let accentColor = backgroundColor.accentColor()
            
            logPrint("🎨 Updating auto colors - contrast: \(contrastColor), accent: \(accentColor)")
            
            // Оновлюємо pull-to-refresh колір
            if parent.configuration.ui.pullRefreshColor == "auto",
               let refreshControl = refreshControl {
                refreshControl.tintColor = accentColor
                logPrint("🎨 Updated pull-to-refresh color to accent")
            }
            
            // Оновлюємо колір прогрес-бару
            if parent.configuration.ui.progressBarColor == "auto",
               let progressView = progressView {
                progressView.progressTintColor = accentColor
                logPrint("🎨 Updated progress bar color to accent")
            }
            
            // Оновлюємо кольори кнопок навігації
            if parent.configuration.ui.menuButtonColor == "auto" {
                for button in navigationButtons {
                    button.tintColor = contrastColor
                }
                logPrint("🎨 Updated navigation buttons color to contrast")
            }
            
            // Оновлюємо кольори адаптивної навігаційної панелі тільки якщо фон або кнопки в auto режимі
            if parent.configuration.ui.menuBackgroundColor == "auto" || parent.configuration.ui.menuButtonColor == "auto" {
                adaptiveNavigationManager?.updateColorsForAutoMode(
                    backgroundColor: backgroundColor,
                    buttonColor: contrastColor,
                    shouldUpdateBackground: parent.configuration.ui.menuBackgroundColor == "auto",
                    shouldUpdateButtons: parent.configuration.ui.menuButtonColor == "auto"
                )
            }
        }
        
    }
}
