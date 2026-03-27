import Foundation
import CryptoKit
import Security

/// Сервис для безопасного шифрования и дешифрования данных
class SecureStorageService {
    static let shared = SecureStorageService()
    
    private let keyAlias = "SecureStorageEncryptionKey"
    private var cachedKey: SymmetricKey?
    
    private init() {}
    
    // MARK: - Performance Logging
    
    /// Измеряет время выполнения операции и логирует результат
    private func measureTime<T>(operation: String, for key: String? = nil, _ block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // в миллисекундах
        
        let keyInfo = key.map { " (\($0))" } ?? ""
        logPrint("🔐 \(operation)\(keyInfo): \(String(format: "%.2f", timeElapsed))ms")
        
        return result
    }
    
    // MARK: - Encryption Key Management
    
    /// Получает или создает ключ шифрования
    private func getOrCreateEncryptionKey() -> SymmetricKey {
        if let cachedKey = cachedKey {
            return cachedKey
        }
        
        // Пытаемся получить существующий ключ из Keychain
        if let existingKey = getKeyFromKeychain() {
            cachedKey = existingKey
            return existingKey
        }
        
        // Создаем новый ключ и сохраняем его в Keychain
        let newKey = SymmetricKey(size: .bits256)
        saveKeyToKeychain(newKey)
        cachedKey = newKey
        return newKey
    }
    
    /// Сохраняет ключ в Keychain
    private func saveKeyToKeychain(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyAlias,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Удаляем существующий ключ, если есть
        SecItemDelete(query as CFDictionary)
        
        // Добавляем новый ключ
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            logPrint("⚠️ Ошибка сохранения ключа в Keychain: \(status)")
        }
    }
    
    /// Получает ключ из Keychain
    private func getKeyFromKeychain() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyAlias,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let keyData = result as? Data else {
            return nil
        }
        
        return SymmetricKey(data: keyData)
    }
    
    // MARK: - Encryption/Decryption
    
    /// Шифрует данные
    func encrypt<T: Codable>(_ value: T) -> Data? {
        return measureTime(operation: "Шифрование") {
            do {
                let jsonData = try JSONEncoder().encode(value)
                let key = getOrCreateEncryptionKey()
                let sealedBox = try AES.GCM.seal(jsonData, using: key)
                return sealedBox.combined
            } catch {
                logPrint("⚠️ Ошибка шифрования: \(error)")
                return nil
            }
        }
    }
    
    /// Дешифрует данные
    func decrypt<T: Codable>(_ data: Data, as type: T.Type) -> T? {
        return measureTime(operation: "Дешифрование") {
            do {
                let key = getOrCreateEncryptionKey()
                let sealedBox = try AES.GCM.SealedBox(combined: data)
                let decryptedData = try AES.GCM.open(sealedBox, using: key)
                return try JSONDecoder().decode(type, from: decryptedData)
            } catch {
                logPrint("⚠️ Ошибка дешифрования: \(error)")
                return nil
            }
        }
    }
    
    /// Шифрует строку
    func encryptString(_ string: String) -> Data? {
        return encrypt(string)
    }
    
    /// Дешифрует строку
    func decryptString(_ data: Data) -> String? {
        return decrypt(data, as: String.self)
    }
    
    /// Шифрует Data
    func encryptData(_ data: Data) -> Data? {
        return measureTime(operation: "Шифрование Data") {
            do {
                let key = getOrCreateEncryptionKey()
                let sealedBox = try AES.GCM.seal(data, using: key)
                return sealedBox.combined
            } catch {
                logPrint("⚠️ Ошибка шифрования Data: \(error)")
                return nil
            }
        }
    }
    
    /// Дешифрует Data
    func decryptData(_ encryptedData: Data) -> Data? {
        return measureTime(operation: "Дешифрование Data") {
            do {
                let key = getOrCreateEncryptionKey()
                let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                return try AES.GCM.open(sealedBox, using: key)
            } catch {
                logPrint("⚠️ Ошибка дешифрования Data: \(error)")
                return nil
            }
        }
    }
}
