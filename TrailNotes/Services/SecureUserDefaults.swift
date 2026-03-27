import Foundation


class SecureUserDefaults {
    static let standard = SecureUserDefaults()
    
    private let userDefaults: UserDefaults
    private let encryptionService: SecureStorageService
    
    private init() {
        self.userDefaults = UserDefaults.standard
        self.encryptionService = SecureStorageService.shared
    }
    
    // MARK: - Performance Logging
    
    /// Измеряет время выполнения операции и логирует результат
    private func measureTime<T>(operation: String, key: String, _ block: () -> T) -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = block()
        let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // в миллисекундах
        
        logPrint("💾 \(operation) (\(key)): \(String(format: "%.2f", timeElapsed))ms")
        
        return result
    }
    
    // MARK: - String Methods
    
    /// Сохраняет зашифрованную строку
    func set(_ value: String, forKey key: String) {
        measureTime(operation: "Запись строки", key: key) {
            guard let encryptedData = encryptionService.encryptString(value) else {
                logPrint("⚠️ Не удалось зашифровать строку для ключа: \(key)")
                return
            }
            userDefaults.set(encryptedData, forKey: key)
        }
    }
    
    /// Получает и дешифрует строку
    func string(forKey key: String) -> String? {
        return measureTime(operation: "Чтение строки", key: key) {
            guard let encryptedData = userDefaults.data(forKey: key) else {
                return nil
            }
            return encryptionService.decryptString(encryptedData)
        }
    }
    
    // MARK: - Data Methods
    
    /// Сохраняет зашифрованные данные
    func set(_ value: Data, forKey key: String) {
        measureTime(operation: "Запись данных", key: key) {
            guard let encryptedData = encryptionService.encryptData(value) else {
                logPrint("⚠️ Не удалось зашифровать данные для ключа: \(key)")
                return
            }
            userDefaults.set(encryptedData, forKey: key)
        }
    }
    
    /// Получает и дешифрует данные
    func data(forKey key: String) -> Data? {
        return measureTime(operation: "Чтение данных", key: key) {
            guard let encryptedData = userDefaults.data(forKey: key) else {
                return nil
            }
            return encryptionService.decryptData(encryptedData)
        }
    }
    
    // MARK: - Date Methods
    
    /// Сохраняет зашифрованную дату
    func set(_ value: Date, forKey key: String) {
        measureTime(operation: "Запись даты", key: key) {
            guard let encryptedData = encryptionService.encrypt(value) else {
                logPrint("⚠️ Не удалось зашифровать дату для ключа: \(key)")
                return
            }
            userDefaults.set(encryptedData, forKey: key)
        }
    }
    
    /// Получает и дешифрует дату
    func object(forKey key: String) -> Any? {
        guard let encryptedData = userDefaults.data(forKey: key) else {
            return nil
        }
        
        // Пытаемся дешифровать как Date
        if let date = encryptionService.decrypt(encryptedData, as: Date.self) {
            return date
        }
        
        // Если не получилось как Date, возвращаем nil
        return nil
    }
    
    /// Получает и дешифрует Date
    func date(forKey key: String) -> Date? {
        return measureTime(operation: "Чтение даты", key: key) {
            guard let encryptedData = userDefaults.data(forKey: key) else {
                return nil
            }
            return encryptionService.decrypt(encryptedData, as: Date.self)
        }
    }
    
    // MARK: - Double/TimeInterval Methods
    
    /// Сохраняет зашифрованное число с плавающей точкой
    func set(_ value: Double, forKey key: String) {
        measureTime(operation: "Запись Double", key: key) {
            guard let encryptedData = encryptionService.encrypt(value) else {
                logPrint("⚠️ Не удалось зашифровать Double для ключа: \(key)")
                return
            }
            userDefaults.set(encryptedData, forKey: key)
        }
    }
    
    /// Получает и дешифрует число с плавающей точкой
    func double(forKey key: String) -> Double {
        return measureTime(operation: "Чтение Double", key: key) {
            guard let encryptedData = userDefaults.data(forKey: key),
                  let decryptedValue = encryptionService.decrypt(encryptedData, as: Double.self) else {
                return 0.0
            }
            return decryptedValue
        }
    }
    
    /// Получает и дешифрует опциональное число с плавающей точкой
    func optionalDouble(forKey key: String) -> Double? {
        return measureTime(operation: "Чтение Optional Double", key: key) {
            guard let encryptedData = userDefaults.data(forKey: key) else {
                return nil
            }
            return encryptionService.decrypt(encryptedData, as: Double.self)
        }
    }
    
    // MARK: - Integer Methods
    
    /// Сохраняет зашифрованное целое число
    func set(_ value: Int, forKey key: String) {
        measureTime(operation: "Запись Int", key: key) {
            guard let encryptedData = encryptionService.encrypt(value) else {
                logPrint("⚠️ Не удалось зашифровать Int для ключа: \(key)")
                return
            }
            userDefaults.set(encryptedData, forKey: key)
        }
    }
    
    /// Получает и дешифрует целое число
    func integer(forKey key: String) -> Int {
        return measureTime(operation: "Чтение Int", key: key) {
            guard let encryptedData = userDefaults.data(forKey: key),
                  let decryptedValue = encryptionService.decrypt(encryptedData, as: Int.self) else {
                return 0
            }
            return decryptedValue
        }
    }
    
    // MARK: - Boolean Methods
    
    /// Сохраняет зашифрованное булево значение
    func set(_ value: Bool, forKey key: String) {
        measureTime(operation: "Запись Bool", key: key) {
            guard let encryptedData = encryptionService.encrypt(value) else {
                logPrint("⚠️ Не удалось зашифровать Bool для ключа: \(key)")
                return
            }
            userDefaults.set(encryptedData, forKey: key)
        }
    }
    
    /// Получает и дешифрует булево значение
    func bool(forKey key: String) -> Bool {
        return measureTime(operation: "Чтение Bool", key: key) {
            guard let encryptedData = userDefaults.data(forKey: key),
                  let decryptedValue = encryptionService.decrypt(encryptedData, as: Bool.self) else {
                return false
            }
            return decryptedValue
        }
    }
    
    // MARK: - Generic Codable Methods
    
    /// Сохраняет любой Codable объект в зашифрованном виде
    func setCodable<T: Codable>(_ value: T, forKey key: String) {
        measureTime(operation: "Запись Codable", key: key) {
            guard let encryptedData = encryptionService.encrypt(value) else {
                logPrint("⚠️ Не удалось зашифровать Codable объект для ключа: \(key)")
                return
            }
            userDefaults.set(encryptedData, forKey: key)
        }
    }
    
    /// Получает и дешифрует Codable объект
    func getCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        return measureTime(operation: "Чтение Codable", key: key) {
            guard let encryptedData = userDefaults.data(forKey: key) else {
                return nil
            }
            return encryptionService.decrypt(encryptedData, as: type)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Удаляет значение по ключу
    func removeObject(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    /// Синхронизирует изменения
    func synchronize() -> Bool {
        return userDefaults.synchronize()
    }
    
    /// Проверяет существование значения по ключу
    func hasValue(forKey key: String) -> Bool {
        return userDefaults.data(forKey: key) != nil
    }
}
