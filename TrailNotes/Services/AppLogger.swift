//
//  AppLogger.swift
//  NewGrayTemplate
//
//  Утиліта для управління логами в додатку
//

import Foundation

/// Глобальний менеджер логів додатку
class AppLogger {
    /// Singleton instance
    static let shared = AppLogger()
    
    /// Флаг для вмикання/вимикання всіх логів
    /// true = логи виводяться
    /// false = всі print() ігноруються
    var logsEnabled: Bool = true
    
    private init() {}
    
    /// Виводить лог тільки якщо logsEnabled = true
    /// - Parameter message: Повідомлення для виводу
    func log(_ message: String) {
        guard logsEnabled else { return }
        print(message)
    }
    
    /// Виводить лог з префіксом тільки якщо logsEnabled = true
    /// - Parameters:
    ///   - prefix: Префікс (наприклад, "✅", "❌", "🔒")
    ///   - message: Повідомлення
    func log(_ prefix: String, _ message: String) {
        guard logsEnabled else { return }
        print("\(prefix) \(message)")
    }
}

/// Глобальна функція для швидкого доступу до логів
/// Замість print() використовуємо logPrint()
func logPrint(_ message: String) {
    AppLogger.shared.log(message)
}

