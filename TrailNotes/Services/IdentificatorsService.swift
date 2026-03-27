import Foundation

class IdentificatorsService {
    static let shared = IdentificatorsService()
    private let defaults = SecureUserDefaults.standard
    private let keychain = KeychainService.shared
    
    private let uuidKey = "user_id_key_value"
    private let keychainUuidKey = "device_id_keychain_key" // Ключ для Keychain
    private let randomUserIdKey = "user_random_key_value"
    private let firstOpenTimeKey = "openfirsttime_value"
    
     init() {
        if !defaults.hasValue(forKey: firstOpenTimeKey) {

            defaults.set(Date(), forKey: firstOpenTimeKey)
            
            let randomUserId = UUID().uuidString
            defaults.set(randomUserId, forKey: randomUserIdKey)
        }
    }
    
    
    /// Получает или создает Device ID с приоритетом:
    /// 1. Keychain (переживает переустановку)
    /// 2. UserDefaults (миграция для существующих пользователей)
    /// 3. Генерация нового
    func getOrCreateUUID() -> UUID {
        // Шаг 1: Проверяем Keychain (приоритет)
        if let keychainUUIDString = keychain.getString(forKey: keychainUuidKey),
           let keychainUUID = UUID(uuidString: keychainUUIDString) {
            logPrint("✅ [DeviceID] Получен из Keychain: \(keychainUUIDString)")
            
            // Синхронизируем с UserDefaults на всякий случай
            if defaults.string(forKey: uuidKey) != keychainUUIDString {
                defaults.set(keychainUUIDString, forKey: uuidKey)
                defaults.synchronize()
            }
            
            return keychainUUID
        }
        
        // Шаг 2: Проверяем UserDefaults (миграция для существующих пользователей)
        if let userDefaultsUUIDString = defaults.string(forKey: uuidKey),
           let userDefaultsUUID = UUID(uuidString: userDefaultsUUIDString) {
            logPrint("🔄 [DeviceID] Найден в UserDefaults, мигрируем в Keychain: \(userDefaultsUUIDString)")
            
            // Сохраняем в Keychain для будущих использований
            keychain.saveString(userDefaultsUUIDString, forKey: keychainUuidKey)
            
            return userDefaultsUUID
        }
        
        // Шаг 3: Генерируем новый Device ID
        let newUUID = generateUUID()
        let newUUIDString = newUUID.uuidString
        
        logPrint("🆕 [DeviceID] Создан новый: \(newUUIDString)")
        
        // Сохраняем в Keychain (главное хранилище)
        keychain.saveString(newUUIDString, forKey: keychainUuidKey)
        
        // Сохраняем в UserDefaults (резервное хранилище)
        defaults.set(newUUIDString, forKey: uuidKey)
        defaults.synchronize()
        
        return newUUID
    }
    
    func getRandomUserId() -> String? {
        return defaults.string(forKey: randomUserIdKey)?.lowercased()
    }
    
    func getFirstOpenDate() -> Date? {
        return defaults.date(forKey: firstOpenTimeKey)
    }
    
    private func get64LeastSignificantBitsForVersion1() -> Int64 {
        let random = Int64.random(in: 0...Int64.max)
        let random63BitLong = random & 0x3FFFFFFFFFFFFFFF
        let variant3BitFlag = Int64.min
        return random63BitLong | variant3BitFlag
    }
    
    private func get64MostSignificantBitsForVersion1() -> Int64 {
        let currentTimeMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let timeLow = (currentTimeMillis & 0x00000000FFFFFFFF) << 32
        let timeMid = ((currentTimeMillis >> 32 ) & 0xFFFF) << 16
        let version: Int64 = 1 << 12
        let timeHi = (currentTimeMillis >> 48) & 0x0FFF
        return timeLow | timeMid | version | timeHi
    }
    
    private func generateType1UUID() -> UUID {
        var most64SigBits = get64MostSignificantBitsForVersion1()
        var least64SigBits = get64LeastSignificantBitsForVersion1()
        let mostData = Data(bytes: &most64SigBits, count: MemoryLayout<Int64>.size)
        let leastData = Data(bytes: &least64SigBits, count: MemoryLayout<Int64>.size)
        let bytes = [UInt8](mostData) + [UInt8](leastData)
        let tuple: uuid_t = (bytes[7], bytes[6], bytes[5], bytes[4],
                           bytes[3], bytes[2], bytes[1], bytes[0],
                           bytes[15], bytes[14], bytes[13], bytes[12],
                           bytes[11], bytes[10], bytes[9], bytes[8])
        
        return UUID(uuid: tuple)
    }
    
    func generateUUID() -> UUID {
        return generateType1UUID()
    }
    
    // MARK: - Debug / Testing
    
    /// 🔥 ПАСХАЛКА ДЛЯ ТЕСТЕРОВ: Полный сброс всех данных
    /// Удаляет Device ID из Keychain и UserDefaults, симулирует чистую установку
    func resetAllIdentifiers() {
        logPrint("🔥 [DEBUG] Полный сброс всех идентификаторов!")
        
        // Удаляем Device ID из Keychain
        keychain.delete(forKey: keychainUuidKey)
        logPrint("🗑️ Device ID удален из Keychain")
        
        // Удаляем Device ID из UserDefaults
        defaults.removeObject(forKey: uuidKey)
        logPrint("🗑️ Device ID удален из UserDefaults")
        
        // Удаляем Random User ID
        defaults.removeObject(forKey: randomUserIdKey)
        logPrint("🗑️ Random User ID удален")
        
        // Удаляем First Open Date
        defaults.removeObject(forKey: firstOpenTimeKey)
        logPrint("🗑️ First Open Date удален")
        
        defaults.synchronize()
        logPrint("✅ [DEBUG] Все данные сброшены! Перезапустите приложение для чистой установки")
    }
} 
