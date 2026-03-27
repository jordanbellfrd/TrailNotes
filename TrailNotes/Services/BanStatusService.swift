import Foundation

// MARK: - Ban Status Response (unified)
struct BanStatusResponse {
    let isBanned: Bool
    let bannedAt: String?
    let pushes: [ServerPush]?
    let schedules: [PushSchedule]?
    
    // Init from API response (200 = banned)
    init(banned schedules: [PushSchedule]?, templates: [PushTemplate]?) {
        self.isBanned = true
        self.bannedAt = Date().ISO8601Format()
        self.schedules = schedules
        
        // Get device language (fallback to English)
        let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        print("🌍 [BanStatus] Device language: \(deviceLanguage)")
        
        // Convert templates to pushes using device language
        self.pushes = templates?.compactMap { template in
            template.toServerPush(language: deviceLanguage)
        }
        
        print("📦 [BanStatus] Converted \(templates?.count ?? 0) templates to \(self.pushes?.count ?? 0) pushes")
        print("📅 [BanStatus] Schedules: \(schedules?.count ?? 0)")
    }
    
    // Init for "not banned" case (400)
    init(notBanned message: String) {
        self.isBanned = false
        self.bannedAt = nil
        self.pushes = nil
        self.schedules = nil
    }
    
    // Init for cached fallback (already has converted pushes)
    init(cachedSchedules: [PushSchedule]) {
        self.isBanned = true
        self.bannedAt = Date().ISO8601Format()
        self.schedules = cachedSchedules
        self.pushes = nil  // Pushes already in StoredPush format in storage
    }
}

// MARK: - Raw API Response Wrapper (NEW FORMAT - Multiple Companies)
struct BannedAppAPIResponseWrapper: Codable {
    let companies: [String: BannedAppAPIResponse]
    
    // Custom decoder to parse dynamic company keys
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.companies = try container.decode([String: BannedAppAPIResponse].self)
    }
    
    // Merge all schedules and templates from all companies
    func mergeAll() -> BannedAppAPIResponse {
        var allSchedules: [PushSchedule] = []
        var allTemplates: [PushTemplate] = []
        
        for (companyName, companyData) in companies {
            print("📦 [BanStatus] Company: \(companyName)")
            if let schedules = companyData.schedules {
                print("   └─ Schedules: \(schedules.count)")
                allSchedules.append(contentsOf: schedules)
            }
            if let templates = companyData.templates {
                print("   └─ Templates: \(templates.count)")
                allTemplates.append(contentsOf: templates)
            }
        }
        
        print("✅ [BanStatus] Total: \(companies.count) companies, \(allSchedules.count) schedules, \(allTemplates.count) templates")
        
        return BannedAppAPIResponse(
            schedules: allSchedules.isEmpty ? nil : allSchedules,
            templates: allTemplates.isEmpty ? nil : allTemplates
        )
    }
}

// MARK: - Raw API Response (200 OK - App is BANNED)
struct BannedAppAPIResponse: Codable {
    let schedules: [PushSchedule]?
    let templates: [PushTemplate]?
}

// MARK: - Not Banned Response (400 - App is NOT banned)
struct NotBannedResponse: Codable {
    let message: String
    let error: String?
    let statusCode: Int
}

// MARK: - Schedule (from API)
struct PushSchedule: Codable {
    let id: String?
    let time: String?              // "13:13"
    let type: String?              // "weekly", "daily", "once"
    let dayOfWeek: Int?            // 0-6 (Sunday-Saturday)
    let days: [Int]?               // Array of days (NEW)
    let dayOfMonth: Int?           // Day of month (NEW)
    let useLastActiveTime: Bool?
    let useRandomTemplate: Bool?
    let templateId: String?        // Specific template ID (NEW)
}

// MARK: - Push Template (from API)
struct PushTemplate: Codable {
    let id: String?
    let name: String?
    let title: [String: String]?   // Multilingual: {"en": "Title", "fr": "Titre"}
    let subtitle: [String: String]? // Может быть null или пустым массивом []
    let body: [String: String]?    // Multilingual: {"en": "Body", "fr": "Corps"}
    let imageUrl: String?
    let deepLink: String?
    let geo: [String]?
    
    // Custom decoder для обработки subtitle (может быть [] или null)
    enum CodingKeys: String, CodingKey {
        case id, name, title, subtitle, body, imageUrl, deepLink, geo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        title = try container.decodeIfPresent([String: String].self, forKey: .title)
        body = try container.decodeIfPresent([String: String].self, forKey: .body)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        deepLink = try container.decodeIfPresent(String.self, forKey: .deepLink)
        geo = try container.decodeIfPresent([String].self, forKey: .geo)
        
        // Обрабатываем subtitle - может быть [] или null или словарем
        if let subtitleDict = try? container.decodeIfPresent([String: String].self, forKey: .subtitle) {
            subtitle = subtitleDict
        } else {
            // Если не словарь (например, пустой массив []), игнорируем
            subtitle = nil
        }
    }
    
    // Convert to ServerPush with user's language
    func toServerPush(language: String = "en") -> ServerPush? {
        guard let title = title?[language] ?? title?["en"],
              let body = body?[language] ?? body?["en"] else {
            return nil
        }
        
        return ServerPush(
            id: id,
            title: title,
            body: body,
            badge: nil,
            sound: "default",
            customPayload: [
                "deepLink": deepLink ?? "",
                "imageUrl": imageUrl ?? "",
                "templateId": id ?? ""
            ].filter { !$0.value.isEmpty }
        )
    }
}

// MARK: - Ban Status Service Configuration
struct BanStatusConfig {
    /// 🔑 API Token для Authorization: Bearer (не используется в новой логике)
    /// Теперь используется domain из AppDelegate
    static let apiToken = "deprecated" // Токен теперь не нужен
}

// MARK: - Ban Status Service
class BanStatusService {
    static let shared = BanStatusService()
    
    private init() {}
    
    // MARK: - Check Ban Status (NEW LOGIC with apns_ban flag)
    func checkBanStatus(domain: String, completion: @escaping (Result<BanStatusResponse, Error>) -> Void) {
        // 1️⃣ Check apns_ban flag from server response (saved in UserDefaults)
        let apnsBanEnabled = SecureUserDefaults.standard.bool(forKey: "apns_ban")
        
        print("📋 [BanStatus] apns_ban from server: \(apnsBanEnabled)")
        
        guard apnsBanEnabled else {
            print("❌ [BanStatus] apns_ban = false, skipping ban check")
            let response = BanStatusResponse(notBanned: "apns_ban is disabled in config")
            completion(.success(response))
            return
        }
        
        // 2️⃣ If apns_ban = true, fetch push schedule from server
        let deviceId = getDeviceId()
        
        // Construct URL: GET https://domain.com/push/{device_id}/list
        let urlString = "\(domain)/push/\(deviceId)/list"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "BanStatusService", code: -2, 
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔍 [BanStatus] GET \(urlString)")
        print("🔑 [BanStatus] Device ID: \(deviceId)")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [BanStatus] Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "BanStatusService", code: -4, 
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            print("📡 [BanStatus] Response status: \(httpResponse.statusCode)")
            
            guard let data = data else {
                completion(.failure(NSError(domain: "BanStatusService", code: -3, 
                    userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📦 [BanStatus] Response: \(responseString)")
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                // 200 = Schedules received, parse and schedule local pushes
                do {
                    // Decode new format with dynamic company keys
                    let wrapper = try JSONDecoder().decode(BannedAppAPIResponseWrapper.self, from: data)
                    print("🏢 [BanStatus] Received data for \(wrapper.companies.count) companies")
                    
                    // Merge all companies' schedules and templates
                    let apiResponse = wrapper.mergeAll()
                    
                    // 💾 Cache schedules for fallback
                    if let schedules = apiResponse.schedules {
                        PushStorageService.shared.cacheSchedules(schedules)
                    }
                    
                    let response = BanStatusResponse(banned: apiResponse.schedules, templates: apiResponse.templates)
                    print("✅ [BanStatus] Pushes to schedule: \(response.pushes?.count ?? 0)")
                    completion(.success(response))
                } catch {
                    print("❌ [BanStatus] Decode error (200): \(error)")
                    self.tryFallbackToCachedSchedules(completion: completion)
                }
                
            case 400:
                // 400 = No schedules for this device → Try fallback to cached schedules
                print("⚠️ [BanStatus] API returned 400 (no schedules)")
                self.tryFallbackToCachedSchedules(completion: completion)
                
            default:
                // 500+ or other errors → Try fallback to cached schedules
                print("⚠️ [BanStatus] API error (status: \(httpResponse.statusCode))")
                self.tryFallbackToCachedSchedules(completion: completion)
            }
        }
        
        task.resume()
    }
    
    // MARK: - Fallback to Cached Schedules
    private func tryFallbackToCachedSchedules(completion: @escaping (Result<BanStatusResponse, Error>) -> Void) {
        // Пытаемся загрузить кэшированные schedules
        if let cachedSchedules = PushStorageService.shared.loadCachedSchedules(),
           !cachedSchedules.isEmpty {
            
            // Загружаем сохраненные pushes (templates)
            let cachedPushes = PushStorageService.shared.loadPushes()
            
            if !cachedPushes.isEmpty {
                print("✅ [BanStatus] Using cached schedules (\(cachedSchedules.count)) and pushes (\(cachedPushes.count)) as fallback")
                
                // Создаем response из кэша
                let response = BanStatusResponse(cachedSchedules: cachedSchedules)
                
                completion(.success(response))
                return
            }
        }
        
        // Если кэша нет - возвращаем "не забанен"
        print("⚠️ [BanStatus] No cached schedules available, treating as not banned")
        let response = BanStatusResponse(notBanned: "No schedules available (API error + no cache)")
        completion(.success(response))
    }
    
    // MARK: - Get Device ID
    private func getDeviceId() -> String {
//        #if DEBUG
//        // В DEBUG режиме используем тестовый device_id
//        if let testId = BanStatusConfig.testDeviceId {
//            print("🧪 [BanStatus] Using TEST device_id: \(testId)")
//            return testId
//        }
//        #endif
        
        // Используем device_id из IdentificatorsService (работает с Keychain + UserDefaults)
        // ВАЖНО: .lowercased() - для консистентности с MainInfoDictionary и трекингом
        let deviceId = IdentificatorsService.shared.getOrCreateUUID().uuidString.lowercased()
        print("📱 [BanStatus] Using device_id from IdentificatorsService: \(deviceId)")
        return deviceId
    }
    
    // MARK: - Save Last Check Time
    private let lastCheckKey = "last_ban_check"
    
    func saveLastCheckTime() {
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
    }
    
    func getLastCheckTime() -> Date? {
        return UserDefaults.standard.object(forKey: lastCheckKey) as? Date
    }
}


