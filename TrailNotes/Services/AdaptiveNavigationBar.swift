//
//  AdaptiveNavigationBar.swift
//  NewGrayTemplate
//
//  Created by Assistant on 17.09.2025.
//

import UIKit
import WebKit

// MARK: - Adaptive Navigation Bar
class AdaptiveNavigationBar: UIView {
    
    // MARK: - Properties
    private var buttons: [UIButton] = []
    private var stackView: UIStackView!
    private var backgroundView: UIView!
    private var buttonConfigs: [NavigationButtonConfig] = []
    
    // Layout constraints
    private var portraitConstraints: [NSLayoutConstraint] = []
    private var landscapeConstraints: [NSLayoutConstraint] = []
    
    // Збереження останньої валідної орієнтації
    private var lastValidOrientation: UIDeviceOrientation = .portrait
    
    // Configuration
    var panelBackgroundColor: UIColor = UIColor(red: 0.06, green: 0.49, blue: 0.25, alpha: 0.95) {
        didSet { updateBackgroundColor() }
    }
    
    var buttonTintColor: UIColor = .white {
        didSet { updateButtonColors() }
    }
    
    var isStatic: Bool = true
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        
        // Дозволяємо дотики поза межами view для landscape режиму
        clipsToBounds = false
        
        // Background view
        setupBackgroundView()
        
        // Stack view для кнопок
        setupStackView()
        
        // Спостереження за орієнтацією
        setupOrientationObserver()
    }
    
    private func setupBackgroundView() {
        backgroundView = UIView()
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = panelBackgroundColor
        
        addSubview(backgroundView)
    }
    
    private func setupStackView() {
        stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.alignment = .center
        stackView.spacing = 8
        addSubview(stackView)
    }
    
    private func setupOrientationObserver() {
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
            logPrint("🔄 NavigationBar: Initialized with portrait orientation (current was invalid: \(currentOrientation.rawValue))")
        } else {
            lastValidOrientation = currentOrientation
            logPrint("🔄 NavigationBar: Initialized with current orientation: \(currentOrientation.rawValue)")
        }
    }
    
    @objc private func orientationDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateLayoutForCurrentOrientation()
        }
    }
    
    private func updateLayoutForCurrentOrientation() {
        let currentOrientation = UIDevice.current.orientation
        
        // Ігноруємо portraitUpsideDown - залишаємо попередню орієнтацію
        if currentOrientation == .portraitUpsideDown {
            logPrint("🚫 NavigationBar: Ignoring portraitUpsideDown - keeping last valid orientation: \(lastValidOrientation.rawValue)")
            return
        }
        
        // Ігноруємо також невалідні орієнтації (faceUp, faceDown, unknown)
        guard currentOrientation == .portrait || 
              currentOrientation == .landscapeLeft || 
              currentOrientation == .landscapeRight else {
            logPrint("🚫 NavigationBar: Ignoring invalid orientation: \(currentOrientation.rawValue)")
            return
        }
        
        // Зберігаємо валідну орієнтацію
        lastValidOrientation = currentOrientation
        
        // Деактивуємо всі constraints
        NSLayoutConstraint.deactivate(portraitConstraints + landscapeConstraints)
        
        switch currentOrientation {
        case .landscapeLeft:
            // Камера зліва -> панель справа, заокруглені кути зліва
            setupLandscapeLayout(isLeft: true)
            NSLayoutConstraint.activate(landscapeConstraints)
            logPrint("🔄 NavigationBar layout updated for landscapeLeft (panel on RIGHT)")
            
        case .landscapeRight:
            // Камера справа -> панель зліва, заокруглені кути справа
            setupLandscapeLayout(isLeft: false)
            NSLayoutConstraint.activate(landscapeConstraints)
            logPrint("🔄 NavigationBar layout updated for landscapeRight (panel on LEFT)")
            
        case .portrait:
            // Портретний режим
            setupPortraitLayout()
            NSLayoutConstraint.activate(portraitConstraints)
            logPrint("🔄 NavigationBar layout updated for portrait")
            
        default:
            break
        }
        
        // Анімуємо зміни
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.layoutIfNeeded()
        }
    }
    
    private func setupPortraitLayout() {
        // Portrait: горизонтальний layout, панель внизу на всю ширину
        stackView.axis = .horizontal
        stackView.spacing = 8
        
        // Прибираємо заокруглені кути для повноширинного режиму
        backgroundView.layer.cornerRadius = 0
        backgroundView.layer.maskedCorners = []
        
        portraitConstraints = [
            // Background view
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Stack view - піднімаємо вище центру
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            stackView.heightAnchor.constraint(equalToConstant: 44)
        ]
    }
    
    private func setupLandscapeLayout(isLeft: Bool) {
        // Landscape: вертикальний layout з фіксованими розмірами кнопок
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fill
        stackView.alignment = .center
        
        // Прибираємо заокруглені кути для landscape режиму
        backgroundView.layer.cornerRadius = 0
        backgroundView.layer.maskedCorners = []
        
        landscapeConstraints = [
            // Background view
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Stack view - центруємо з фіксованими розмірами кнопок
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.widthAnchor.constraint(equalToConstant: 44)
        ]
    }
    
    // MARK: - Public Methods
    func configure(with buttonConfigs: [NavigationButtonConfig]) {
        self.buttonConfigs = buttonConfigs
        createButtons()
        applyLayoutForOrientation(lastValidOrientation)
    }
    
    private func applyLayoutForOrientation(_ orientation: UIDeviceOrientation) {
        // Деактивуємо всі constraints
        NSLayoutConstraint.deactivate(portraitConstraints + landscapeConstraints)
        
        switch orientation {
        case .landscapeLeft:
            setupLandscapeLayout(isLeft: true)
            NSLayoutConstraint.activate(landscapeConstraints)
            
        case .landscapeRight:
            setupLandscapeLayout(isLeft: false)
            NSLayoutConstraint.activate(landscapeConstraints)
            
        default: // .portrait або будь-яка інша
            setupPortraitLayout()
            NSLayoutConstraint.activate(portraitConstraints)
        }
        
        layoutIfNeeded()
    }
    
    func updateButtonStates(canGoBack: Bool, canGoForward: Bool) {
        for button in buttons {
            guard let identifier = button.accessibilityIdentifier,
                  let type = NavigationButtonType(rawValue: identifier) else {
                continue
            }
            
            switch type {
            case .back:
                updateButtonState(button, isEnabled: canGoBack)
            case .forward:
                updateButtonState(button, isEnabled: canGoForward)
            default:
                updateButtonState(button, isEnabled: true)
            }
        }
    }
    
    // MARK: - Private Methods
    private func createButtons() {
        // Очищуємо попередні кнопки
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        stackView.arrangedSubviews.forEach { stackView.removeArrangedSubview($0) }
        
        // Створюємо нові кнопки
        for config in buttonConfigs {
            let button = createButton(for: config)
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
        
        logPrint("🎯 Created \(buttons.count) adaptive navigation buttons")
    }
    
    private func createButton(for config: NavigationButtonConfig) -> UIButton {
        let button = UIButton(type: .system)
        
        // Налаштовуємо зображення
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: config.systemImage, withConfiguration: imageConfig)
        button.setImage(image, for: .normal)
        button.tintColor = buttonTintColor
        
        // Accessibility
        button.accessibilityLabel = config.type.accessibilityLabel
        button.accessibilityIdentifier = config.type.rawValue
        
        // Стиль кнопки
        button.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        button.layer.cornerRadius = 22
        
        // Розміри
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Дії
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpOutside, .touchCancel])
        
        // Початковий стан
        updateButtonState(button, isEnabled: config.isEnabled)
        
        return button
    }
    
    private func updateButtonState(_ button: UIButton, isEnabled: Bool) {
        button.isEnabled = isEnabled
        
        UIView.animate(withDuration: 0.2) {
            button.alpha = isEnabled ? 1.0 : 0.5
            button.backgroundColor = isEnabled ? 
                UIColor.white.withAlphaComponent(0.15) : 
                UIColor.white.withAlphaComponent(0.08)
        }
    }
    
    private func updateBackgroundColor() {
        backgroundView?.backgroundColor = panelBackgroundColor
    }
    
    private func updateButtonColors() {
        buttons.forEach { $0.tintColor = buttonTintColor }
    }
    
    // MARK: - Button Actions
    @objc private func buttonTapped(_ sender: UIButton) {
        guard let identifier = sender.accessibilityIdentifier,
              let type = NavigationButtonType(rawValue: identifier),
              let config = buttonConfigs.first(where: { $0.type == type }) else { return }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Виконуємо дію
        config.action()
        
        logPrint("🎯 Button tapped: \(type.accessibilityLabel)")
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        // Плавніша анімація натискання з spring ефектом
        UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .beginFromCurrentState]) {
            sender.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            sender.backgroundColor = UIColor.white.withAlphaComponent(0.30)
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        // Повернення до нормального стану з м'яким spring
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [.allowUserInteraction, .beginFromCurrentState]) {
            sender.transform = .identity
            sender.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        }
    }
    
    // MARK: - Auto Color Support
    
    /// Оновлює кольори для auto режиму на основі кольору сторінки
    func updateColorsForAutoMode(backgroundColor: UIColor, buttonColor: UIColor, shouldUpdateBackground: Bool, shouldUpdateButtons: Bool) {
        // Обчислюємо кольори на основі фону сторінки
        let adaptedBackgroundColor = backgroundColor.withAlphaComponent(0.9)
        let contrastColor = backgroundColor.contrastColor()
        
        // Запам'ятовуємо чи панель була прихована (для першого показу)
        let wasHidden = self.alpha < 0.1
        
        // Оновлюємо колір фону панелі тільки якщо він в auto режимі
        if shouldUpdateBackground {
            self.panelBackgroundColor = adaptedBackgroundColor
            updateBackgroundColor()
            logPrint("🎨 AdaptiveNavigationBar: Updated background color to \(adaptedBackgroundColor)")
        }
        
        // Оновлюємо колір кнопок тільки якщо вони в auto режимі
        if shouldUpdateButtons {
            self.buttonTintColor = contrastColor
            updateButtonColors()
            logPrint("🎨 AdaptiveNavigationBar: Updated button colors to \(contrastColor)")
        }
        
        // 🎬 Плавно показуємо панель при першому визначенні кольору
        if wasHidden {
            UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseOut]) {
                self.alpha = 1.0
            }
            logPrint("✨ AdaptiveNavigationBar: Smoothly appeared after color detection")
        }
    }
    
    // MARK: - Hit Testing
    
    /// Розширюємо область натискання для кнопок
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // ❌ Ігноруємо клики якщо панель схована (alpha близка до 0)
        if alpha < 0.01 {
            return nil
        }
        
        // ❌ Ігноруємо клики якщо взаємодія вимкнена
        if !isUserInteractionEnabled {
            return nil
        }
        
        // Спочатку перевіряємо стандартний hit test
        if let hitView = super.hitTest(point, with: event) {
            return hitView
        }
        
        // Якщо точка поза межами view, перевіряємо кнопки з розширеною областю
        for subview in stackView.arrangedSubviews {
            if let button = subview as? UIButton {
                let buttonPoint = convert(point, to: button)
                let expandedBounds = button.bounds.insetBy(dx: -20, dy: -20)
                
                if expandedBounds.contains(buttonPoint) {
                    return button
                }
            }
        }
        
        return nil
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Configuration Extensions
extension AdaptiveNavigationBar {
    
    func applyConfiguration(_ config: UIConfig) {
        // Визначаємо чи колір в auto режимі
        let isBackgroundAuto = config.menuBackgroundColor == "auto"
        let isButtonColorAuto = config.menuButtonColor == "auto"
        
        // Колір фону
        if let bgColorHex = config.menuBackgroundColor {
            if bgColorHex == "auto" {
                // Для auto режиму використовуємо стандартний колір, 
                // який буде оновлений через updateColorsForAutoMode
                panelBackgroundColor = UIColor(red: 0.06, green: 0.49, blue: 0.25, alpha: 0.95)
                logPrint("🎨 Menu background set to auto mode")
            } else {
                panelBackgroundColor = UIColor(hex: bgColorHex) ?? UIColor(red: 0.06, green: 0.49, blue: 0.25, alpha: 0.95)
            }
        }
        
        // Колір кнопок
        if let buttonColorHex = config.menuButtonColor {
            if buttonColorHex == "auto" {
                // Для auto режиму використовуємо білий колір за замовчуванням,
                // який буде оновлений через updateColorsForAutoMode
                buttonTintColor = .white
                logPrint("🎨 Menu buttons set to auto mode")
            } else {
                buttonTintColor = UIColor(hex: buttonColorHex) ?? .white
            }
        }
        
        // Статичне меню
        isStatic = config.navigationMenuStatic
        
        // 🎬 Для auto режиму починаємо невидимими (щоб уникнути мелькання зеленим)
        // Панель з'явиться плавно після визначення кольору сторінки
        if isBackgroundAuto || isButtonColorAuto {
            alpha = 0.0
            logPrint("🎨 Navigation bar hidden initially (auto mode) - will appear after color detection")
        } else {
            // Для не-auto режиму одразу видима
            alpha = 1.0
            logPrint("🎨 Navigation bar visible immediately (fixed color mode)")
        }
        
        transform = .identity
        isUserInteractionEnabled = true
        
        logPrint("🎨 Navigation bar configured - static: \(isStatic), alpha: \(alpha)")
    }
}
