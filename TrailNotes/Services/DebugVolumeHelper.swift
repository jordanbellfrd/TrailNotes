import UIKit
import SwiftUI

/// 🎯 ПАСХАЛКА ДЛЯ ТЕСТЕРОВ: 3 скриншота подряд за 3 секунды → Сброс всех данных
/// Активируется только если сервер отправляет debugModeEnabled = true
class DebugScreenshotHelper {
    static let shared = DebugScreenshotHelper()
    
    private var screenshotCount: Int = 0
    private var firstScreenshotTime: Date?
    private var isProcessingReset: Bool = false
    private var isActive: Bool = false // Флаг активности
    
    private let requiredScreenshots: Int = 3
    private let screenshotTimeout: TimeInterval = 3.0
    
    private init() {
        // По умолчанию не активен - ждем флаг с сервера
        logPrint("📸 [DEBUG] DebugScreenshotHelper initialized (inactive, waiting for server flag)")
    }
    
    /// Activate screenshot listener (called when server sends debugModeEnabled = true)
    func activate() {
        guard !isActive else {
            logPrint("📸 [DEBUG] Screenshot listener already active")
            return
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        
        isActive = true
        logPrint("✅ [DEBUG] Screenshot listener ACTIVATED: take 3 screenshots in 3 sec to reset")
    }
    
    /// Deactivate screenshot listener (called when server sends debugModeEnabled = false)
    func deactivate() {
        guard isActive else {
            logPrint("📸 [DEBUG] Screenshot listener already inactive")
            return
        }
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        
        // Reset counters
        screenshotCount = 0
        firstScreenshotTime = nil
        isProcessingReset = false
        isActive = false
        
        logPrint("❌ [DEBUG] Screenshot listener DEACTIVATED")
    }
    
    @objc private func handleScreenshot() {
        // Ignore screenshots if already processing reset
        if isProcessingReset {
                return
            }
        
        let now = Date()
        
        // Check if this is first screenshot or continuation
        if let firstScreenshot = firstScreenshotTime {
            let timeSinceFirstScreenshot = now.timeIntervalSince(firstScreenshot)
            
            // Reset if timeout exceeded
            if timeSinceFirstScreenshot > screenshotTimeout {
                screenshotCount = 1
                firstScreenshotTime = now
                logPrint("📸 [DEBUG] Screenshot 1/\(requiredScreenshots)")
                return
            }
        } else {
            // First screenshot
            firstScreenshotTime = now
        }
        
        // Increment screenshot count
        screenshotCount += 1
        
        // Log progress
        logPrint("📸 [DEBUG] Screenshot \(screenshotCount)/\(requiredScreenshots)")
        
        // Check if required screenshots reached
        if screenshotCount >= requiredScreenshots {
            logPrint("✅ [DEBUG] \(requiredScreenshots) screenshots detected! Showing reset alert...")
            
            // Reset counters
            screenshotCount = 0
            firstScreenshotTime = nil
            isProcessingReset = true
            
            // Haptic feedback
                let feedbackGenerator = UINotificationFeedbackGenerator()
                feedbackGenerator.notificationOccurred(.warning)
                
            // Show alert
            DispatchQueue.main.async { [weak self] in
                Self.showResetAlert()
                
                // Reset flag after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self?.isProcessingReset = false
                    logPrint("🔄 [DEBUG] isProcessingReset flag reset")
                }
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Show reset confirmation alert
    static func showResetAlert() {
        logPrint("📸 [DEBUG] 3 screenshots detected! Showing reset alert...")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            logPrint("⚠️ [DEBUG] Failed to find rootViewController")
            return
        }
        
        let alert = UIAlertController(
            title: "🔥 Debug: Reset App Data",
            message: "Are you sure you want to COMPLETELY RESET all app data?\n\n• Device ID (Keychain)\n• Device ID (UserDefaults)\n• Random User ID\n• First Open Date\n\n⚠️ After reset, you must DELETE and REINSTALL the app manually to generate a new Device ID.",
            preferredStyle: .alert
        )
        
        // Confirmation button (red, destructive)
        alert.addAction(UIAlertAction(title: "🔥 Reset Everything", style: .destructive) { _ in
            performReset()
        })
        
        // Cancel button
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Показываем alert поверх всего
        DispatchQueue.main.async {
            // Ищем самый верхний presented view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            topController.present(alert, animated: true)
        }
    }
    
    private static func performReset() {
        logPrint("🔥🔥🔥 [DEBUG] STARTING FULL DATA RESET!")
        
        // Reset all identifiers
        IdentificatorsService.shared.resetAllIdentifiers()
        
        // Show final notification
        let successAlert = UIAlertController(
            title: "✅ Reset Complete",
            message: "All data deleted!\n\n⚠️ Now DELETE the app and REINSTALL it manually.\n\nApp will close in 2 seconds...",
            preferredStyle: .alert
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }),
           let rootVC = window.rootViewController {
            
            DispatchQueue.main.async {
                var topController = rootVC
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                
                topController.present(successAlert, animated: true)
                
                // Close app after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    logPrint("🔄 [DEBUG] Closing app...")
                    exit(0) // Close app (user will reinstall manually)
                }
            }
        }
    }
}

