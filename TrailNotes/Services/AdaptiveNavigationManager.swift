//
//  AdaptiveNavigationManager.swift
//  NewGrayTemplate
//
//  Created by Assistant on 17.09.2025.
//

import UIKit
import WebKit

// MARK: - Animation Styles
enum NavigationAnimationStyle: String, CaseIterable {
    case standard = "Standard Spring"
    case fadeAndSlide = "Fade & Slide"
    case morphAndScale = "Morph & Scale"
    case elasticBounce = "Elastic Bounce"
    case liquidMorph = "Liquid Morph"
    case flipTransition = "3D Flip"
    
    var description: String {
        return self.rawValue
    }
}

// MARK: - Animation Configuration
struct NavigationAnimationConfig {
    static var currentStyle: NavigationAnimationStyle = .fadeAndSlide
    static var enableHapticFeedback: Bool = true
    static var enableBlurEffect: Bool = false
}

// MARK: - Adaptive Navigation Manager
class AdaptiveNavigationManager: NSObject {
    
    // MARK: - Properties
    private weak var webView: WKWebView?
    private weak var containerView: UIView?
    private var navigationBar: AdaptiveNavigationBar?
    private var configuration: WebViewConfiguration
    private var initialURL: URL?
    private weak var bottomTapZone: UIView? // Зберігаємо reference на зону
    
    // Layout constraints
    private var portraitConstraints: [NSLayoutConstraint] = []
    private var landscapeConstraints: [NSLayoutConstraint] = []
    
    // Збереження останньої валідної орієнтації
    private var lastValidOrientation: UIDeviceOrientation = .portrait
    
    // Safari-подібна поведінка скролу
    var isNavigationBarVisible: Bool = true
    private var isManuallyHiddenByUser: Bool = false // Флаг: користувач вручну сховав navbar
    private var hideNavigationTimer: Timer?
    private var lastScrollOffset: CGFloat = 0
    private var scrollVelocity: CGFloat = 0
    private var lastScrollTime: CFTimeInterval = 0
    
    // Інтерактивне слідування за скролом
    private var navigationBarProgress: CGFloat = 1.0 // 0.0 = схована, 1.0 = видима
    private var isInteractivelyScrolling: Bool = false
    private var lastConstraintState: Bool = true // true = constraints для видимої панелі
    
    // MARK: - Initialization
    init(configuration: WebViewConfiguration) {
        self.configuration = configuration
        self.lastScrollTime = CACurrentMediaTime()
        // Для статичного меню панель завжди видима, для динамічного - починає як видима
        self.isNavigationBarVisible = true
        super.init()
        setupOrientationObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        hideNavigationTimer?.invalidate()
    }
    
    private func setupOrientationObserver() {
        // Якщо navigationMenu вимкнено - не потрібен observer
        guard configuration.ui.navigationMenuEnabled else {
            logPrint("🚫 Navigation menu disabled - orientation observer not needed")
            return
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // Ініціалізуємо з правильною орієнтацією при старті
        initializeWithValidOrientation()
    }
    
    private func initializeWithValidOrientation() {
        let currentOrientation = UIDevice.current.orientation
        
        // Якщо запускаємося в portraitUpsideDown або невалідній орієнтації, 
        // встановлюємо portrait як початкову
        if currentOrientation == .portraitUpsideDown || 
           (currentOrientation != .portrait && 
            currentOrientation != .landscapeLeft && 
            currentOrientation != .landscapeRight) {
            lastValidOrientation = .portrait
            logPrint("🔄 Initialized with portrait orientation (current was invalid: \(currentOrientation.rawValue))")
        } else {
            lastValidOrientation = currentOrientation
            logPrint("🔄 Initialized with current orientation: \(currentOrientation.rawValue)")
        }
    }
    
    @objc private func orientationDidChange() {
        // Якщо navigationMenu вимкнено - не обробляємо зміну орієнтації
        guard configuration.ui.navigationMenuEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateLayoutForCurrentOrientation()
        }
    }
    
    // MARK: - Setup
    func setupNavigation(in containerView: UIView, webView: WKWebView, initialURL: URL) {
        self.containerView = containerView
        self.webView = webView
        self.initialURL = initialURL
        
        // Якщо navigationMenu вимкнено - просто встановлюємо constraints для WebView на весь екран
        guard configuration.ui.navigationMenuEnabled else {
            setupWebViewOnlyLayout()
            logPrint("🎯 Navigation menu disabled - WebView takes full screen")
            return
        }
        
        // Для статичного меню панель завжди видима
        if configuration.ui.navigationMenuStatic {
            isNavigationBarVisible = true
            logPrint("🔒 Static navigation menu - bar will always be visible")
        }
        
        createNavigationBar()
        configureNavigationBar()
        setupInitialLayout()
        
        // Переконуємося що navigationBar зверху після повної ініціалізації
        if let navigationBar = navigationBar {
            containerView.bringSubviewToFront(navigationBar)
        }
        
        // Додаємо tap gesture ЗАВЖДИ (працює і для статичного, і для динамічного меню)
        setupTapGesture(in: containerView)
        logPrint("👆 Tap gesture enabled for navbar control")
        
        logPrint("🎯 Adaptive Navigation Manager setup completed")
    }
    
    /// Встановлює layout для WebView без navigationBar (на весь екран)
    private func setupWebViewOnlyLayout() {
        guard let containerView = containerView, let webView = webView else { return }
        
        // Отримуємо стандартні safe area insets
        let safeAreaInsets = getSafeAreaInsets()
        let artificialSafeAreaTop = max(safeAreaInsets.top, 44) // Мінімум 44px зверху
        
        // Встановлюємо constraints для WebView на весь екран
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: artificialSafeAreaTop),
            webView.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        logPrint("📱 WebView layout set to full screen (no navigation bar)")
    }
    
    private func setupTapGesture(in containerView: UIView) {
        // Створюємо невидиму зону внизу для тапів (50px)
        let tapZone = UIView()
        tapZone.backgroundColor = .clear // Прозора
        tapZone.translatesAutoresizingMaskIntoConstraints = false
        tapZone.isUserInteractionEnabled = false // Спочатку вимкнена (navbar видимий)
        tapZone.layer.zPosition = 9999 // Поверх усього
        
        // Зберігаємо reference
        self.bottomTapZone = tapZone
        
        // Додаємо поверх усього
        containerView.addSubview(tapZone)
        containerView.bringSubviewToFront(tapZone)
        
        // Constraints - невидима зона 50px знизу
        NSLayoutConstraint.activate([
            tapZone.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tapZone.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tapZone.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            tapZone.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // 👆 Додаємо простий TAP для перемикання navbar
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSimpleTap))
        tapZone.addGestureRecognizer(tapGesture)
        
        logPrint("👆 Invisible tap zone (50px) created at bottom - initially DISABLED")
    }
    
    /// 👆 Обробник простого тапу - ТІЛЬКИ відкриває сховану панель
    @objc private func handleSimpleTap() {
        logPrint("👆 Tap on bottom zone - isNavigationBarVisible: \(isNavigationBarVisible)")
        
        // Зона працює ТІЛЬКИ якщо navbar схована
        if !isNavigationBarVisible {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Користувач вручну відкрив navbar - скидаємо флаг
            isManuallyHiddenByUser = false
            
            // Показуємо панель
            showNavigationBarAnimated()
            scheduleHideNavigation()
            logPrint("✅ Showing navbar from bottom tap - user manually opened")
        } else {
            logPrint("⏭️ Navbar visible - bottom tap ignored")
        }
    }
    
    private func createNavigationBar() {
        guard let containerView = containerView else { return }
        
        navigationBar = AdaptiveNavigationBar()
        navigationBar?.translatesAutoresizingMaskIntoConstraints = false
        
        // Встановлюємо початковий стан (повністю видима)
        navigationBar?.alpha = 1.0
        navigationBar?.transform = .identity
        navigationBar?.isUserInteractionEnabled = true // ✅ Увімкнути взаємодію на старті
        
        // Дозволяємо елементам виходити за межі контейнера
        containerView.clipsToBounds = false
        
        containerView.addSubview(navigationBar!)
        
        // Переконуємося що navigationBar завжди ЗВЕРХУ всіх інших views
        containerView.bringSubviewToFront(navigationBar!)
    }
    
    private func configureNavigationBar() {
        guard let navigationBar = navigationBar else { return }
        
        // Застосовуємо конфігурацію
        navigationBar.applyConfiguration(configuration.ui)
        
        // Створюємо кнопки
        let buttonConfigs = createButtonConfigs()
        navigationBar.configure(with: buttonConfigs)
        
        logPrint("🎯 Navigation bar configured with \(buttonConfigs.count) buttons")
        
        // 🎬 Fallback: якщо через 2 секунди панель все ще невидима (сторінка не визначила колір),
        // показуємо її з дефолтним кольором
        if configuration.ui.menuBackgroundColor == "auto" || configuration.ui.menuButtonColor == "auto" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self, weak navigationBar] in
                guard let navBar = navigationBar, navBar.alpha < 0.1 else { return }
                
                logPrint("⚠️ Fallback: Showing navbar with default color (page didn't provide color)")
                UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseOut]) {
                    navBar.alpha = 1.0
                }
            }
        }
    }
    
    private func setupInitialLayout() {
        guard let containerView = containerView,
              let webView = webView,
              let navigationBar = navigationBar else { return }
        
        // Застосовуємо layout на основі збереженої валідної орієнтації
        // Для статичного меню панель завжди видима
        let initialBarVisibility = configuration.ui.navigationMenuStatic || isNavigationBarVisible
        applyLayoutForOrientation(lastValidOrientation, containerView: containerView, webView: webView, navigationBar: navigationBar, isBarVisible: initialBarVisibility)
    }
    
    private func applyLayoutForOrientation(_ orientation: UIDeviceOrientation, containerView: UIView, webView: WKWebView, navigationBar: AdaptiveNavigationBar, isBarVisible: Bool = true) {
        // Деактивуємо всі constraints
        NSLayoutConstraint.deactivate(portraitConstraints + landscapeConstraints)
        
        switch orientation {
        case .landscapeLeft:
            landscapeConstraints = createLandscapeLeftConstraints(containerView: containerView, webView: webView, navigationBar: navigationBar, isBarVisible: isBarVisible)
            NSLayoutConstraint.activate(landscapeConstraints)
            logPrint("🔄 Applied initial layout for landscapeLeft (bar visible: \(isBarVisible))")
            
        case .landscapeRight:
            landscapeConstraints = createLandscapeRightConstraints(containerView: containerView, webView: webView, navigationBar: navigationBar, isBarVisible: isBarVisible)
            NSLayoutConstraint.activate(landscapeConstraints)
            logPrint("🔄 Applied initial layout for landscapeRight (bar visible: \(isBarVisible))")
            
        default: // .portrait або будь-яка інша
            portraitConstraints = createPortraitConstraints(containerView: containerView, webView: webView, navigationBar: navigationBar, isBarVisible: isBarVisible)
            NSLayoutConstraint.activate(portraitConstraints)
            logPrint("🔄 Applied initial layout for portrait (bar visible: \(isBarVisible))")
        }
    }
    
    private func createPortraitConstraints(containerView: UIView, webView: WKWebView, navigationBar: AdaptiveNavigationBar, isBarVisible: Bool = true) -> [NSLayoutConstraint] {
        // Отримуємо стандартні safe area insets для створення штучної safe area
        let safeAreaInsets = getSafeAreaInsets()
        let artificialSafeAreaTop = max(safeAreaInsets.top, 44) // Мінімум 44px зверху
        
        var constraints: [NSLayoutConstraint] = [
            // Navigation bar на всю ширину екрану та торкається низу з нульовим відступом
            navigationBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            navigationBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            navigationBar.heightAnchor.constraint(equalToConstant: 70),
            
            // WebView зі штучною safe area зверху
            webView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: artificialSafeAreaTop),
            webView.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor)
        ]
        
        // Змінюємо bottom constraint залежно від видимості панелі
        if isBarVisible {
            // Панель видима - WebView приліплений до верху панелі
            constraints.append(webView.bottomAnchor.constraint(equalTo: navigationBar.topAnchor))
        } else {
            // Панель схована - WebView займає весь простір до низу
            constraints.append(webView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor))
        }
        
        return constraints
    }
    
    private func createLandscapeLeftConstraints(containerView: UIView, webView: WKWebView, navigationBar: AdaptiveNavigationBar, isBarVisible: Bool = true) -> [NSLayoutConstraint] {
        // landscapeLeft: камера зліва, панель справа на всю висоту екрану
        let safeAreaInsets = getSafeAreaInsets()
        
        var constraints: [NSLayoutConstraint] = [
            navigationBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            navigationBar.topAnchor.constraint(equalTo: containerView.topAnchor),
            navigationBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            navigationBar.widthAnchor.constraint(equalToConstant: 60),

            // WebView constraints (без safe area знизу для landscape)
            webView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ]
        
        // Змінюємо trailing constraint залежно від видимості панелі
        if isBarVisible {
            // Панель видима - WebView приліплений до лівого краю панелі
            let artificialSafeAreaRight = max(safeAreaInsets.right, 60)
            constraints.append(webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -artificialSafeAreaRight))
        } else {
            // Панель схована - WebView займає весь простір до правого краю
            constraints.append(webView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor))
        }
        
        return constraints
    }
    
    private func createLandscapeRightConstraints(containerView: UIView, webView: WKWebView, navigationBar: AdaptiveNavigationBar, isBarVisible: Bool = true) -> [NSLayoutConstraint] {
        // landscapeRight: камера справа, панель зліва на всю висоту екрану
        let safeAreaInsets = getSafeAreaInsets()
        
        var constraints: [NSLayoutConstraint] = [
            navigationBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            navigationBar.topAnchor.constraint(equalTo: containerView.topAnchor),
            navigationBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            navigationBar.widthAnchor.constraint(equalToConstant: 60),

            // WebView constraints (без safe area знизу для landscape)
            webView.topAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.topAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ]
        
        // Змінюємо leading constraint залежно від видимості панелі
        if isBarVisible {
            // Панель видима - WebView приліплений до правого краю панелі
            let artificialSafeAreaLeft = max(safeAreaInsets.left, 60)
            constraints.append(webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: artificialSafeAreaLeft))
        } else {
            // Панель схована - WebView займає весь простір до лівого краю
            constraints.append(webView.leadingAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.leadingAnchor))
        }
        
        return constraints
    }
    
    private func updateLayoutForCurrentOrientation() {
        guard let containerView = containerView,
              let webView = webView,
              let navigationBar = navigationBar else { return }
        
        let currentOrientation = UIDevice.current.orientation
        
        // Ігноруємо portraitUpsideDown - залишаємо попередню орієнтацію
        if currentOrientation == .portraitUpsideDown {
            logPrint("🚫 Ignoring portraitUpsideDown - keeping last valid orientation: \(lastValidOrientation.rawValue)")
            return
        }
        
        // Ігноруємо також невалідні орієнтації (faceUp, faceDown, unknown)
        guard currentOrientation == .portrait || 
              currentOrientation == .landscapeLeft || 
              currentOrientation == .landscapeRight else {
            logPrint("🚫 Ignoring invalid orientation: \(currentOrientation.rawValue)")
            return
        }
        
        // Зберігаємо валідну орієнтацію
        lastValidOrientation = currentOrientation
        
        // Деактивуємо всі constraints
        NSLayoutConstraint.deactivate(portraitConstraints + landscapeConstraints)
        
        switch currentOrientation {
        case .landscapeLeft:
            // Камера зліва -> панель справа (зі сторони зарядки)
            landscapeConstraints = createLandscapeLeftConstraints(containerView: containerView, webView: webView, navigationBar: navigationBar)
            NSLayoutConstraint.activate(landscapeConstraints)
            logPrint("🔄 Updated layout for landscapeLeft (panel on RIGHT side)")
            
        case .landscapeRight:
            // Камера справа -> панель зліва (зі сторони зарядки)
            landscapeConstraints = createLandscapeRightConstraints(containerView: containerView, webView: webView, navigationBar: navigationBar)
            NSLayoutConstraint.activate(landscapeConstraints)
            logPrint("🔄 Updated layout for landscapeRight (panel on LEFT side)")
            
        case .portrait:
            // Портретний режим
            NSLayoutConstraint.activate(portraitConstraints)
            logPrint("🔄 Updated layout for portrait orientation")
            
        default:
            break
        }
        
        // Анімуємо зміни з обраним стилем
        animateOrientationChange(
            navigationBar: navigationBar,
            webView: webView,
            containerView: containerView,
            style: NavigationAnimationConfig.currentStyle
        )
    }
    
    private func createButtonConfigs() -> [NavigationButtonConfig] {
        var configs: [NavigationButtonConfig] = []
        
        for buttonName in configuration.ui.enabledButtons {
            guard let buttonType = mapButtonName(buttonName) else {
                logPrint("⚠️ Unknown button type: \(buttonName)")
                continue
            }
            
            let config = NavigationButtonConfig(type: buttonType) { [weak self] in
                self?.handleButtonAction(buttonType)
            }
            configs.append(config)
        }
        
        return configs
    }
    
    private func mapButtonName(_ name: String) -> NavigationButtonType? {
        switch name.lowercased() {
        case "back": return .back
        case "forward": return .forward
        case "home": return .home
        case "reload": return .reload
        case "share": return .share
        case "bookmark": return .bookmark
        case "close": return .close
        case "settings": return .settings
        default: return nil
        }
    }
    
    // MARK: - Button Actions
    private func handleButtonAction(_ type: NavigationButtonType) {
        guard let webView = webView else { return }
        
        // Для кнопки close не показуємо панель - вона має ховати
        if type != .close {
            // Після взаємодії з кнопками показуємо панель і плануємо ховання (якщо не статичне меню)
            if !isNavigationBarVisible {
                showNavigationBarAnimated()
            }
            scheduleHideNavigation()
        }
        
        switch type {
        case .back:
            if webView.canGoBack {
                webView.goBack()
                // Оновлюємо стан кнопок одразу після навігації
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.updateNavigationState()
                }
            }
            
        case .forward:
            if webView.canGoForward {
                webView.goForward()
                // Оновлюємо стан кнопок одразу після навігації
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.updateNavigationState()
                }
            }
            
        case .home:
            if let initialURL = initialURL {
                webView.load(URLRequest(url: initialURL))
                // Оновлюємо стан кнопок одразу після навігації
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.updateNavigationState()
                }
            }
            
        case .reload:
            webView.reload()
            // Оновлюємо стан кнопок одразу після перезавантаження
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateNavigationState()
            }
            
        case .share:
            shareCurrentPage()
            
        case .bookmark:
            bookmarkCurrentPage()
            
        case .close:
            // Просто ховаємо панель (можна відкрити тапом по нижній зоні)
            isManuallyHiddenByUser = true // Запам'ятовуємо що користувач сховав вручну
            hideNavigationBarAnimated()
            logPrint("❌ [NAVIGATION] Panel closed by user - tap bottom to reopen")
            
        case .settings:
            showAnimationSettings()
        }
    }
    
    private func shareCurrentPage() {
        guard let webView = webView,
              let url = webView.url,
              let containerView = containerView else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Знаходимо view controller для презентації
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var presentingViewController = rootViewController
            while let presented = presentingViewController.presentedViewController {
                presentingViewController = presented
            }
            
            // Для iPad налаштовуємо popover
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = containerView
                popover.sourceRect = CGRect(x: containerView.bounds.midX, y: containerView.bounds.maxY - 100, width: 0, height: 0)
            }
            
            presentingViewController.present(activityViewController, animated: true)
        }
    }
    
    private func bookmarkCurrentPage() {
        guard let webView = webView, let url = webView.url else { return }
        logPrint("📖 Bookmark page: \(url.absoluteString)")
        // Тут можна додати логіку збереження закладок
    }
    
    private func hideNavigationBar() {
        navigationBar?.alpha = 0.0
    }
    
    private func showAnimationSettings() {
        guard let containerView = containerView else { return }
        
        // Знаходимо view controller для презентації
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var presentingViewController = rootViewController
            while let presented = presentingViewController.presentedViewController {
                presentingViewController = presented
            }
            
            let alertController = UIAlertController(
                title: "🎨 Animation Settings",
                message: "Choose animation style for orientation changes",
                preferredStyle: .actionSheet
            )
            
            // Додаємо всі стилі анімацій
            for style in NavigationAnimationStyle.allCases {
                let action = UIAlertAction(title: style.description, style: .default) { _ in
                    NavigationAnimationConfig.currentStyle = style
                    logPrint("🎨 Animation style changed to: \(style.description)")
                    
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
                
                // Позначаємо поточний стиль
                if style == NavigationAnimationConfig.currentStyle {
                    action.setValue(true, forKey: "checked")
                }
                
                alertController.addAction(action)
            }
            
            // Додаємо розділювач
            alertController.addAction(UIAlertAction(title: "", style: .default, handler: nil))
            
            // Haptic Feedback toggle
            let hapticTitle = NavigationAnimationConfig.enableHapticFeedback ? 
                "🔇 Disable Haptic Feedback" : "🔊 Enable Haptic Feedback"
            alertController.addAction(UIAlertAction(title: hapticTitle, style: .default) { _ in
                NavigationAnimationConfig.enableHapticFeedback.toggle()
                logPrint("🔊 Haptic feedback: \(NavigationAnimationConfig.enableHapticFeedback)")
            })
            
            // Blur Effect toggle
            let blurTitle = NavigationAnimationConfig.enableBlurEffect ? 
                "🚫 Disable Blur Effect" : "✨ Enable Blur Effect"
            alertController.addAction(UIAlertAction(title: blurTitle, style: .default) { _ in
                NavigationAnimationConfig.enableBlurEffect.toggle()
                logPrint("✨ Blur effect: \(NavigationAnimationConfig.enableBlurEffect)")
            })
            
            // Cancel
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // Для iPad налаштовуємо popover
            if let popover = alertController.popoverPresentationController {
                popover.sourceView = containerView
                popover.sourceRect = CGRect(x: containerView.bounds.midX, y: containerView.bounds.maxY - 100, width: 0, height: 0)
            }
            
            presentingViewController.present(alertController, animated: true)
        }
    }
    
    // MARK: - Public Methods
    
    /// Оновлює кольори навігаційної панелі для auto режиму
    func updateColorsForAutoMode(backgroundColor: UIColor, buttonColor: UIColor, shouldUpdateBackground: Bool, shouldUpdateButtons: Bool) {
        guard let navigationBar = navigationBar else { return }
        
        // Оновлюємо кольори адаптивної навігаційної панелі тільки якщо потрібно
        navigationBar.updateColorsForAutoMode(
            backgroundColor: backgroundColor,
            buttonColor: buttonColor,
            shouldUpdateBackground: shouldUpdateBackground,
            shouldUpdateButtons: shouldUpdateButtons
        )
        
        logPrint("🎨 AdaptiveNavigationManager: Updated colors for auto mode - bg: \(shouldUpdateBackground), buttons: \(shouldUpdateButtons)")
    }
    
    func updateNavigationState() {
        guard let webView = webView, let navigationBar = navigationBar else {
            return
        }
        
        navigationBar.updateButtonStates(
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward
        )
    }
    
    func showNavigationBar(animated: Bool = true) {
        guard let navigationBar = navigationBar else { return }
        
        if animated {
            UIView.animate(withDuration: 0.3) {
                navigationBar.alpha = 1.0
            }
        } else {
            navigationBar.alpha = 1.0
        }
    }
    
    func updateConfiguration(_ newConfig: WebViewConfiguration) {
        self.configuration = newConfig
        navigationBar?.applyConfiguration(newConfig.ui)
        
        // Оновлюємо кнопки
        let buttonConfigs = createButtonConfigs()
        navigationBar?.configure(with: buttonConfigs)
    }
    
    // MARK: - Safari-подібна поведінка скролу
    
    /// Показує навігаційну панель з анімацією (Safari-стиль)
    func showNavigationBarAnimated() {
        guard let navigationBar = navigationBar,
              let containerView = containerView else {
            return
        }
        
        if isNavigationBarVisible {
            return
        }
        
        isNavigationBarVisible = true
        navigationBarProgress = 1.0 // Повністю видима
        lastConstraintState = true // Синхронізуємо стан
        
        // 🚫 Вимикаємо нижню tap зону (navbar видимий - зона не потрібна)
        bottomTapZone?.isUserInteractionEnabled = false
        
        // Оновлюємо constraints для зменшення WebView
        updateWebViewConstraintsForNavigationBarVisible(true)
        
        // 🎨 ПЛАВНАЯ анімація з м'якими параметрами (як у Safari)
        let duration: TimeInterval = 0.65 // Довша анімація для плавності
        let damping: CGFloat = 0.95 // Високе демпфування = менше bounce, більше плавності
        let velocity: CGFloat = 0.2 // Дуже м'який старт
        
        // Визначаємо початкову позицію залежно від орієнтації
        let navigationHeight = getNavigationBarHeight()
        let startTransform: CGAffineTransform
        switch lastValidOrientation {
        case .landscapeLeft:
            // Камера зліва, панель справа - з'являється справа
            startTransform = CGAffineTransform(translationX: navigationHeight, y: 0).scaledBy(x: 0.96, y: 0.96)
        case .landscapeRight:
            // Камера справа, панель зліва - з'являється зліва
            startTransform = CGAffineTransform(translationX: -navigationHeight, y: 0).scaledBy(x: 0.96, y: 0.96)
        default:
            // Portrait - з'являється знизу
            startTransform = CGAffineTransform(translationX: 0, y: navigationHeight).scaledBy(x: 0.96, y: 0.96)
        }
        
        // Початковий стан з більшим scale для м'якшої появи
        navigationBar.transform = startTransform
        navigationBar.alpha = 0.0
        
        // Додаємо невелику затримку для більш природного відчуття
        UIView.animate(withDuration: duration, delay: 0.05, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
            navigationBar.alpha = 1.0
            navigationBar.transform = .identity
            navigationBar.isUserInteractionEnabled = true
            containerView.layoutIfNeeded()
        } completion: { [weak containerView, weak navigationBar] _ in
            // Переконуємося що панель зверху після анімації
            if let navBar = navigationBar, let container = containerView {
                container.bringSubviewToFront(navBar)
            }
        }
        
        // М'який haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            generator.impactOccurred(intensity: 0.4)
        }
    }
    
    /// Ховає навігаційну панель з анімацією (Safari-стиль)
    func hideNavigationBarAnimated() {
        guard let navigationBar = navigationBar,
              let containerView = containerView else {
            return
        }
        
        if !isNavigationBarVisible {
            return
        }
        
        
        isNavigationBarVisible = false
        navigationBarProgress = 0.0 // Повністю схована
        lastConstraintState = false // Синхронізуємо стан
        resetHideTimer()
        
        // ✅ Вмикаємо нижню tap зону (navbar схований - зона активна для відкриття)
        bottomTapZone?.isUserInteractionEnabled = true
        
        // Оновлюємо constraints для збільшення WebView
        updateWebViewConstraintsForNavigationBarVisible(false)
        
        // 🎨 ПЛАВНАЯ анімація приховування (трохи швидше ніж показ)
        let duration: TimeInterval = 0.55 // Довша анімація для плавності
        let damping: CGFloat = 0.96 // Дуже високе демпфування для м'якого зникнення
        let velocity: CGFloat = 0.15 // Дуже м'який старт
        let navigationHeight: CGFloat = getNavigationBarHeight()
        
        // Визначаємо напрямок ховання залежно від орієнтації
        let hideTransform: CGAffineTransform
        switch lastValidOrientation {
        case .landscapeLeft:
            // Камера зліва, панель справа - ховається вправо
            hideTransform = CGAffineTransform(translationX: navigationHeight, y: 0).scaledBy(x: 0.96, y: 0.96)
        case .landscapeRight:
            // Камера справа, панель зліва - ховається вліво
            hideTransform = CGAffineTransform(translationX: -navigationHeight, y: 0).scaledBy(x: 0.96, y: 0.96)
        default:
            // Portrait - ховається вниз
            hideTransform = CGAffineTransform(translationX: 0, y: navigationHeight).scaledBy(x: 0.96, y: 0.96)
        }
        
        // Використовуємо spring для плавного природного руху
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: [.curveEaseIn, .allowUserInteraction, .beginFromCurrentState]) {
            navigationBar.alpha = 0.0
            navigationBar.transform = hideTransform
            containerView.layoutIfNeeded()
        } completion: { [weak navigationBar] _ in
            // Вимкнути взаємодію після ховання щоб не блокувати WebView
            navigationBar?.isUserInteractionEnabled = false
        }
        
        // М'який haptic feedback при ховані
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            generator.impactOccurred(intensity: 0.25)
        }
    }
    
    /// Оновлює constraints WebView залежно від видимості панелі
    private func updateWebViewConstraintsForNavigationBarVisible(_ visible: Bool) {
        guard let webView = webView,
              let containerView = containerView,
              let navigationBar = navigationBar else {
            return
        }
        
        // Деактивуємо попередні constraints
        NSLayoutConstraint.deactivate(portraitConstraints + landscapeConstraints)
        
        // Створюємо нові constraints залежно від орієнтації та видимості
        switch lastValidOrientation {
        case .landscapeLeft:
            landscapeConstraints = createLandscapeLeftConstraints(
                containerView: containerView,
                webView: webView,
                navigationBar: navigationBar,
                isBarVisible: visible
            )
            NSLayoutConstraint.activate(landscapeConstraints)
            
        case .landscapeRight:
            landscapeConstraints = createLandscapeRightConstraints(
                containerView: containerView,
                webView: webView,
                navigationBar: navigationBar,
                isBarVisible: visible
            )
            NSLayoutConstraint.activate(landscapeConstraints)
            
        default: // .portrait
            portraitConstraints = createPortraitConstraints(
                containerView: containerView,
                webView: webView,
                navigationBar: navigationBar,
                isBarVisible: visible
            )
            NSLayoutConstraint.activate(portraitConstraints)
        }
    }
    
    /// Отримує висоту навігаційної панелі залежно від орієнтації
    private func getNavigationBarHeight() -> CGFloat {
        switch lastValidOrientation {
        case .landscapeLeft, .landscapeRight:
            return 60 // Ширина в landscape
        default:
            return 70 // Висота в portrait
        }
    }
    
    private func resetHideTimer() {
        hideNavigationTimer?.invalidate()
        hideNavigationTimer = nil
    }
    
    private func scheduleHideNavigation() {
        guard isNavigationBarVisible else { return }
        
        // Якщо меню статичне, не ховаємо його
        if configuration.ui.navigationMenuStatic {
            return
        }
        
        // ✅ ФИКС: Если пользователь в конце страницы - не прячем панель автоматически
        if let webView = webView as? WKWebView {
            let scrollView = webView.scrollView
            let currentOffset = scrollView.contentOffset.y
            let contentHeight = scrollView.contentSize.height
            let scrollViewHeight = scrollView.frame.height
            let maxOffset = contentHeight - scrollViewHeight
            let isNearBottom = currentOffset > maxOffset - 50
            
            if isNearBottom {
                logPrint("🔒 [NAVIGATION] Near bottom - keeping bar visible, not scheduling auto-hide")
                return
            }
        }
        
        resetHideTimer()
        // Safari приховує панель через 3 секунди неактивності
        hideNavigationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hideNavigationBarAnimated()
        }
    }
}

// MARK: - UIScrollViewDelegate
extension AdaptiveNavigationManager: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Якщо navigationMenu вимкнено - нічого не робимо
        guard configuration.ui.navigationMenuEnabled else { return }
        
        // Для статичного меню не обробляємо скрол
        if configuration.ui.navigationMenuStatic {
            return
        }
        
        let currentTime = CACurrentMediaTime()
        let currentOffset = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.frame.height
        let maxOffset = contentHeight - scrollViewHeight
        
        // ✅ ФИКС: Игнорируем bounce на границах контента
        let bounceThreshold: CGFloat = 10
        let isBouncingTop = currentOffset < -bounceThreshold
        let isBouncingBottom = currentOffset > maxOffset + bounceThreshold
        
        // Если bounce на границах - не обрабатываем скролл
        if isBouncingTop || isBouncingBottom {
            return
        }
        
        // Обчислюємо швидкість скролу
        let timeDelta = currentTime - lastScrollTime
        if timeDelta > 0.016 { // ~60fps
            let offsetDelta = currentOffset - lastScrollOffset
            
            scrollVelocity = offsetDelta / CGFloat(timeDelta)
            
            // Інтерактивне оновлення позиції панелі під час скролу
            updateNavigationBarProgressInteractively(scrollDelta: offsetDelta, scrollView: scrollView)
            
            lastScrollTime = currentTime
            lastScrollOffset = currentOffset
        }
    }
    
    /// Інтерактивно оновлює позицію панелі під час скролу (як у Safari)
    private func updateNavigationBarProgressInteractively(scrollDelta: CGFloat, scrollView: UIScrollView) {
        guard let navigationBar = navigationBar,
              let webView = webView,
              let containerView = containerView else { return }
        
        let navigationHeight = getNavigationBarHeight()
        let sensitivity: CGFloat = 1.0 // 📏 Чутливість до скролу (менше = більше треба прокрутити)
        
        // ⚠️ Якщо користувач закрив navbar вручну (кнопкою Close),
        // не реагуємо на скрол вгору - navbar залишається схованим
        if isManuallyHiddenByUser && scrollDelta < 0 {
            // Скрол вгору, але navbar закритий юзером - ігноруємо
            navigationBarProgress = 0.0
            return
        }
        
        // ✅ ФИКС: Проверяем границы контента
        let currentOffset = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.frame.height
        let maxOffset = contentHeight - scrollViewHeight
        let nearBottomThreshold: CGFloat = 50
        
        // Если почти в конце страницы и скроллим вниз - не скрываем панель
        let isNearBottom = currentOffset > maxOffset - nearBottomThreshold
        if isNearBottom && scrollDelta > 0 {
            // Фиксируем панель как видимую, чтобы не было дерганья
            navigationBarProgress = 1.0
            return
        }
        
        // Оновлюємо прогрес на основі скролу
        if scrollDelta > 0 {
            // Скрол вниз - ховаємо панель
            navigationBarProgress = max(0.0, navigationBarProgress - (scrollDelta / navigationHeight) * sensitivity)
        } else {
            // Скрол вгору - показуємо панель
            navigationBarProgress = min(1.0, navigationBarProgress - (scrollDelta / navigationHeight) * sensitivity)
        }
        
        // Плавно оновлюємо позицію без анімації (слідує за пальцем)
        let translation = navigationHeight * (1.0 - navigationBarProgress)
        let scale = 0.98 + (navigationBarProgress * 0.02) // від 0.98 до 1.0
        
        // Визначаємо напрямок руху залежно від орієнтації
        let interactiveTransform: CGAffineTransform
        switch lastValidOrientation {
        case .landscapeLeft:
            // Landscape Left - рухається вправо
            interactiveTransform = CGAffineTransform(translationX: translation, y: 0).scaledBy(x: scale, y: scale)
        case .landscapeRight:
            // Landscape Right - рухається вліво
            interactiveTransform = CGAffineTransform(translationX: -translation, y: 0).scaledBy(x: scale, y: scale)
        default:
            // Portrait - рухається вниз
            interactiveTransform = CGAffineTransform(translationX: 0, y: translation).scaledBy(x: scale, y: scale)
        }
        
        navigationBar.transform = interactiveTransform
        navigationBar.alpha = 0.3 + (navigationBarProgress * 0.7) // від 0.3 до 1.0
        
        // Інтерактивно змінюємо constraints для WebView
        updateWebViewConstraintsInteractively(progress: navigationBarProgress)
    }
    
    /// Інтерактивно оновлює constraints WebView під час скролу
    private func updateWebViewConstraintsInteractively(progress: CGFloat) {
        guard let webView = webView,
              let containerView = containerView,
              let navigationBar = navigationBar else { return }
        
        // Визначаємо чи панель достатньо видима для зміни constraints
        let shouldBeVisible = progress > 0.5
        
        // Змінюємо constraints ТІЛЬКИ якщо стан ПЕРЕЙШОВ через порог
        if shouldBeVisible != lastConstraintState {
            lastConstraintState = shouldBeVisible
            
            // Деактивуємо старі constraints
            NSLayoutConstraint.deactivate(portraitConstraints + landscapeConstraints)
            
            // Створюємо і активуємо нові constraints
            switch lastValidOrientation {
            case .landscapeLeft:
                landscapeConstraints = createLandscapeLeftConstraints(
                    containerView: containerView,
                    webView: webView,
                    navigationBar: navigationBar,
                    isBarVisible: shouldBeVisible
                )
                NSLayoutConstraint.activate(landscapeConstraints)
                
            case .landscapeRight:
                landscapeConstraints = createLandscapeRightConstraints(
                    containerView: containerView,
                    webView: webView,
                    navigationBar: navigationBar,
                    isBarVisible: shouldBeVisible
                )
                NSLayoutConstraint.activate(landscapeConstraints)
                
            default:
                portraitConstraints = createPortraitConstraints(
                    containerView: containerView,
                    webView: webView,
                    navigationBar: navigationBar,
                    isBarVisible: shouldBeVisible
                )
                NSLayoutConstraint.activate(portraitConstraints)
            }
        }
    }
    
    /// Плавно завершує анімацію показування (без повторної анімації)
    private func finishShowAnimation() {
        guard let navigationBar = navigationBar,
              let containerView = containerView else { return }
        
        // Перевіряємо чи треба оновити constraints
        let needsConstraintUpdate = !lastConstraintState
        
        // Встановлюємо стан
        isNavigationBarVisible = true
        navigationBarProgress = 1.0
        lastConstraintState = true
        
        // 🚫 Вимикаємо нижню tap зону (navbar видимий)
        bottomTapZone?.isUserInteractionEnabled = false
        
        // Оновлюємо constraints якщо треба
        if needsConstraintUpdate {
            updateWebViewConstraintsForNavigationBarVisible(true)
        }
        
        // 🎨 ПЛАВНО доводимо до кінцевого стану
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.95, initialSpringVelocity: 0.2, options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
            navigationBar.alpha = 1.0
            navigationBar.transform = .identity
            navigationBar.isUserInteractionEnabled = true
            containerView.layoutIfNeeded()
        } completion: { [weak containerView, weak navigationBar] _ in
            // Переконуємося що панель зверху після анімації
            if let navBar = navigationBar, let container = containerView {
                container.bringSubviewToFront(navBar)
            }
        }
    }
    
    /// Плавно завершує анімацію ховання (без повторної анімації)
    private func finishHideAnimation() {
        guard let navigationBar = navigationBar,
              let containerView = containerView else { return }
        
        // Перевіряємо чи треба оновити constraints
        let needsConstraintUpdate = lastConstraintState
        
        // Встановлюємо стан
        isNavigationBarVisible = false
        navigationBarProgress = 0.0
        lastConstraintState = false
        resetHideTimer()
        
        // ✅ Вмикаємо нижню tap зону (navbar схований)
        bottomTapZone?.isUserInteractionEnabled = true
        
        // Оновлюємо constraints якщо треба
        if needsConstraintUpdate {
            updateWebViewConstraintsForNavigationBarVisible(false)
        }
        
        let navigationHeight = getNavigationBarHeight()
        
        // Визначаємо фінальну позицію залежно від орієнтації
        let hideTransform: CGAffineTransform
        switch lastValidOrientation {
        case .landscapeLeft:
            hideTransform = CGAffineTransform(translationX: navigationHeight, y: 0).scaledBy(x: 0.96, y: 0.96)
        case .landscapeRight:
            hideTransform = CGAffineTransform(translationX: -navigationHeight, y: 0).scaledBy(x: 0.96, y: 0.96)
        default:
            hideTransform = CGAffineTransform(translationX: 0, y: navigationHeight).scaledBy(x: 0.96, y: 0.96)
        }
        
        // 🎨 ПЛАВНО доводимо до кінцевого стану
        UIView.animate(withDuration: 0.40, delay: 0, usingSpringWithDamping: 0.96, initialSpringVelocity: 0.15, options: [.curveEaseIn, .allowUserInteraction, .beginFromCurrentState]) {
            navigationBar.alpha = 0.0
            navigationBar.transform = hideTransform
            containerView.layoutIfNeeded()
        } completion: { [weak navigationBar] _ in
            // Вимкнути взаємодію після ховання
            navigationBar?.isUserInteractionEnabled = false
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Якщо navigationMenu вимкнено - нічого не робимо
        guard configuration.ui.navigationMenuEnabled else { return }
        
        // Для статичного меню не обробляємо скрол
        if configuration.ui.navigationMenuStatic {
            return
        }
        
        // Вмикаємо інтерактивний режим
        isInteractivelyScrolling = true
        resetHideTimer()
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Якщо navigationMenu вимкнено - нічого не робимо
        guard configuration.ui.navigationMenuEnabled else { return }
        
        // Для статичного меню не обробляємо скрол
        if configuration.ui.navigationMenuStatic {
            return
        }
        
        // Вимикаємо інтерактивний режим
        isInteractivelyScrolling = false
        
        // Використовуємо офіційний velocity від системи
        let velocityY = velocity.y
        let currentOffset = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.frame.height
        let maxOffset = contentHeight - scrollViewHeight
        
        // Safari-подібна логіка з урахуванням прогресу
        let velocityThreshold: CGFloat = 0.3 // Зменшили поріг для більшої чутливості
        let progressThreshold: CGFloat = 0.5
        let isNearBottom = currentOffset > maxOffset - 50
        
        // Вирішуємо фінальний стан на основі швидкості і прогресу
        let shouldShow: Bool
        
        // Особливий випадок - біля низу завжди показуємо
        if isNearBottom {
            shouldShow = true
        } else if abs(velocityY) > velocityThreshold {
            // Швидкий свайп - рішення на основі напрямку
            shouldShow = velocityY < 0 // Вгору = показати
        } else {
            // Повільний свайп - рішення на основі прогресу
            shouldShow = navigationBarProgress > progressThreshold
        }
        
        // Застосовуємо фінальний стан з анімацією
        if shouldShow {
            // ⚠️ Якщо користувач закрив navbar вручну (кнопкою Close), 
            // не показуємо його при скролі - тільки тап може відкрити
            if isManuallyHiddenByUser {
                logPrint("⏭️ Scroll up detected, but navbar manually closed by user - ignoring")
                // Повертаємо navbar в повністю схований стан без анімації
                if navigationBarProgress > 0 {
                    finishHideAnimation()
                }
                return
            }
            
            // Перевіряємо прогрес - якщо панель вже майже видима, просто доанімовуємо
            if navigationBarProgress >= 0.8 {
                finishShowAnimation()
                scheduleHideNavigation()
            } else if !isNavigationBarVisible {
                showNavigationBarAnimated()
                scheduleHideNavigation()
            } else {
                finishShowAnimation()
                scheduleHideNavigation()
            }
        } else {
            // Перевіряємо прогрес - якщо панель вже майже схована, просто доанімовуємо
            if navigationBarProgress <= 0.2 {
                finishHideAnimation()
            } else if isNavigationBarVisible {
                hideNavigationBarAnimated()
            } else {
                finishHideAnimation()
            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // Якщо navigationMenu вимкнено - нічого не робимо
        guard configuration.ui.navigationMenuEnabled else { return }
        
        // Для статичного меню не обробляємо скрол
        if configuration.ui.navigationMenuStatic {
            return
        }
        
        // ✅ ФИКС: Проверяем что не в конце страницы перед планированием скрытия
        if !decelerate && isNavigationBarVisible {
            scheduleHideNavigation()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Якщо navigationMenu вимкнено - нічого не робимо
        guard configuration.ui.navigationMenuEnabled else { return }
        
        // Для статичного меню не обробляємо скрол
        if configuration.ui.navigationMenuStatic {
            return
        }
        
        // ✅ ФИКС: Проверка теперь внутри scheduleHideNavigation()
        if isNavigationBarVisible {
            scheduleHideNavigation()
        }
    }
}

// MARK: - WKNavigationDelegate
extension AdaptiveNavigationManager: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Оновлюємо стан кнопок одразу при початку навігації
        // Це важливо для свайп-жестів та програмної навігації
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateNavigationState()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateNavigationState()
        
        // Для динамічного меню показуємо панель на мить після завантаження сторінки
        // НО тільки якщо користувач не сховав її вручну
        if !configuration.ui.navigationMenuStatic && !isManuallyHiddenByUser {
            showNavigationBarAnimated()
            scheduleHideNavigation()
            logPrint("📄 Page loaded - showing navbar briefly")
        } else if isManuallyHiddenByUser {
            logPrint("📄 Page loaded - navbar stays hidden (user manually hid it)")
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateNavigationState()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateNavigationState()
    }
    
    // MARK: - Animation Methods
    
    private func animateOrientationChange(
        navigationBar: UIView,
        webView: UIView,
        containerView: UIView,
        style: NavigationAnimationStyle
    ) {
        // Haptic feedback
        if NavigationAnimationConfig.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        // Blur effect
        if NavigationAnimationConfig.enableBlurEffect {
            addTemporaryBlur(to: webView, duration: getDurationForStyle(style))
        }
        
        switch style {
        case .standard:
            animateStandard(navigationBar: navigationBar, webView: webView, containerView: containerView)
        case .fadeAndSlide:
            animateFadeAndSlide(navigationBar: navigationBar, webView: webView, containerView: containerView)
        case .morphAndScale:
            animateMorphAndScale(navigationBar: navigationBar, webView: webView, containerView: containerView)
        case .elasticBounce:
            animateElasticBounce(navigationBar: navigationBar, webView: webView, containerView: containerView)
        case .liquidMorph:
            animateLiquidMorph(navigationBar: navigationBar, webView: webView, containerView: containerView)
        case .flipTransition:
            animateFlipTransition(navigationBar: navigationBar, webView: webView, containerView: containerView)
        }
    }
    
    private func getDurationForStyle(_ style: NavigationAnimationStyle) -> TimeInterval {
        switch style {
        case .standard: return 0.3
        case .fadeAndSlide: return 0.6
        case .morphAndScale: return 0.8
        case .elasticBounce: return 0.8
        case .liquidMorph: return 1.0
        case .flipTransition: return 0.6
        }
    }
    
    // MARK: - Animation Implementations
    
    /// 1. Standard Spring - Поточна анімація
    private func animateStandard(navigationBar: UIView, webView: UIView, containerView: UIView) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            containerView.layoutIfNeeded()
        }
    }
    
    /// 2. Fade & Slide - Елегантне зникнення та поява з нової позиції
    private func animateFadeAndSlide(navigationBar: UIView, webView: UIView, containerView: UIView) {
        // Зберігаємо поточний стан navbar
        let targetAlpha: CGFloat = isNavigationBarVisible ? 1.0 : 0.0
        
        // Phase 1: Fade out з легким зсувом
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut]) {
            navigationBar.alpha = 0.0
            navigationBar.transform = CGAffineTransform(translationX: 0, y: 20).scaledBy(x: 0.95, y: 0.95)
            webView.alpha = 0.95
        } completion: { [weak self] _ in
            // Phase 2: Змінюємо layout
            containerView.layoutIfNeeded()
            
            // Phase 3: Fade in з нової позиції (зберігаємо стан користувача)
            UIView.animate(withDuration: 0.35, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                navigationBar.alpha = targetAlpha // Відновлюємо стан
                navigationBar.transform = .identity
                webView.alpha = 1.0
            }
        }
    }
    
    /// 3. Morph & Scale - Плавне масштабування з морфінгом
    private func animateMorphAndScale(navigationBar: UIView, webView: UIView, containerView: UIView) {
        // Зберігаємо поточний стан navbar
        let targetAlpha: CGFloat = isNavigationBarVisible ? 1.0 : 0.0
        
        // Phase 1: Scale down з rotation
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
            navigationBar.transform = CGAffineTransform(scaleX: 0.1, y: 0.1).rotated(by: .pi / 4)
            navigationBar.alpha = 0.0
            webView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        } completion: { [weak self] _ in
            containerView.layoutIfNeeded()
            
            // Phase 2: Scale up з spring effect (зберігаємо стан користувача)
            navigationBar.transform = CGAffineTransform(scaleX: 0.1, y: 0.1).rotated(by: -.pi / 4)
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                navigationBar.transform = .identity
                navigationBar.alpha = targetAlpha // Відновлюємо стан
                webView.transform = .identity
            }
        }
    }
    
    /// 4. Elastic Bounce - Пружна анімація з відскоком
    private func animateElasticBounce(navigationBar: UIView, webView: UIView, containerView: UIView) {
        // Зберігаємо поточний стан navbar
        let targetAlpha: CGFloat = isNavigationBarVisible ? 1.0 : 0.0
        
        // Phase 1: Compress
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn]) {
            navigationBar.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            navigationBar.alpha = 0.7
        } completion: { [weak self] _ in
            containerView.layoutIfNeeded()
            
            // Phase 2: Elastic bounce (зберігаємо стан користувача)
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 1.2) {
                navigationBar.transform = .identity
                navigationBar.alpha = targetAlpha // Відновлюємо стан
            }
        }
    }
    
    /// 5. Liquid Morph - Плавний "рідкий" перехід
    private func animateLiquidMorph(navigationBar: UIView, webView: UIView, containerView: UIView) {
        // Зберігаємо поточний стан navbar
        let targetAlpha: CGFloat = isNavigationBarVisible ? 1.0 : 0.0
        
        // Phase 1: Liquid dissolve
        let dissolveAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        dissolveAnimation.values = [1.0, 1.1, 0.0]
        dissolveAnimation.keyTimes = [0.0, 0.3, 1.0]
        dissolveAnimation.duration = 0.4
        dissolveAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 1.0
        fadeAnimation.toValue = 0.0
        fadeAnimation.duration = 0.4
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [dissolveAnimation, fadeAnimation]
        animationGroup.duration = 0.4
        animationGroup.fillMode = .forwards
        animationGroup.isRemovedOnCompletion = false
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            containerView.layoutIfNeeded()
            
            // Phase 2: Liquid emerge (зберігаємо стан користувача)
            navigationBar.layer.removeAllAnimations()
            navigationBar.alpha = 0.0
            navigationBar.transform = CGAffineTransform(scaleX: 0.0, y: 0.0)
            
            let emergeAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            emergeAnimation.values = [0.0, 1.2, 0.9, 1.0]
            emergeAnimation.keyTimes = [0.0, 0.4, 0.8, 1.0]
            emergeAnimation.duration = 0.6
            emergeAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            let appearAnimation = CABasicAnimation(keyPath: "opacity")
            appearAnimation.fromValue = 0.0
            appearAnimation.toValue = targetAlpha // Відновлюємо стан
            appearAnimation.duration = 0.6
            
            let emergeGroup = CAAnimationGroup()
            emergeGroup.animations = [emergeAnimation, appearAnimation]
            emergeGroup.duration = 0.6
            
            navigationBar.layer.add(emergeGroup, forKey: "liquidEmerge")
            navigationBar.alpha = targetAlpha // Відновлюємо стан
            navigationBar.transform = .identity
        }
        
        navigationBar.layer.add(animationGroup, forKey: "liquidDissolve")
    }
    
    /// 6. Flip Transition - 3D flip ефект
    private func animateFlipTransition(navigationBar: UIView, webView: UIView, containerView: UIView) {
        // Зберігаємо поточний стан navbar
        let targetAlpha: CGFloat = isNavigationBarVisible ? 1.0 : 0.0
        
        // Phase 1: Flip out
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / 500.0
            transform = CATransform3DRotate(transform, .pi / 2, 0, 1, 0)
            navigationBar.layer.transform = transform
            navigationBar.alpha = 0.0
        } completion: { [weak self] _ in
            containerView.layoutIfNeeded()
            
            // Phase 2: Flip in (зберігаємо стан користувача)
            var transform = CATransform3DIdentity
            transform.m34 = -1.0 / 500.0
            transform = CATransform3DRotate(transform, -.pi / 2, 0, 1, 0)
            navigationBar.layer.transform = transform
            
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut]) {
                navigationBar.layer.transform = CATransform3DIdentity
                navigationBar.alpha = targetAlpha // Відновлюємо стан
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Отримує справжні safe area insets від window
    private func getSafeAreaInsets() -> UIEdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets
        }
        return UIEdgeInsets.zero
    }
    
    /// Створює легкий blur ефект під час анімації
    private func addTemporaryBlur(to view: UIView, duration: TimeInterval) {
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.alpha = 0.0
        blurView.tag = 999 // Для легкого видалення
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.addSubview(blurView)
        
        UIView.animate(withDuration: duration / 2) {
            blurView.alpha = 0.3
        } completion: { _ in
            UIView.animate(withDuration: duration / 2) {
                blurView.alpha = 0.0
            } completion: { _ in
                blurView.removeFromSuperview()
            }
        }
    }
}

