import Foundation
import WebKit

// MARK: - Native Form Detection (Standard WKNavigationDelegate)
class NativeFormDetection: NSObject, WKNavigationDelegate {
    static let shared = NativeFormDetection()
    
    private override init() {
        super.init()
    }
    
    // MARK: - WKNavigationDelegate Methods
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        let request = navigationAction.request
        let urlString = request.url?.absoluteString ?? "unknown"
        
        // Фільтруємо внутрішні браузерні URL
        if urlString.hasPrefix("about:") || urlString.hasPrefix("data:") || urlString.hasPrefix("blob:") {
            decisionHandler(.allow)
            return
        }
        
        // Обробляємо data: image URLs для Share Sheet
        if let url = request.url, url.scheme == "data" {
            let urlString = url.absoluteString
            if urlString.hasPrefix("data:image/") {
                handleDataImageURL(urlString, in: webView)
            }
            decisionHandler(.cancel)
            return
        }
        
        // Логуємо navigation requests (форми, лінки)
        if request.httpMethod == "POST" || navigationAction.navigationType == .formSubmitted {
            let domain = extractDomain(from: urlString)
            logPrint("📋 [NAVIGATION] Form submitted to: \(domain)")
            
            // Аналізуємо POST body якщо доступний
            if let httpBody = request.httpBody {
                analyzeFormSubmission(httpBody, domain: domain)
            }
        }
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        if !["http", "https", "about"].contains(url.scheme) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let urlString = webView.url?.absoluteString ?? "unknown"
        logPrint("🌐 Page loaded: \(urlString)")
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        logPrint("🔄 Loading page: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    // MARK: - Helper Methods
    private func analyzeFormSubmission(_ body: Data, domain: String) {
        guard let bodyString = String(data: body, encoding: .utf8) else {
            logPrint("  📦 Binary form data: \(body.count) bytes")
            return
        }
        
        logPrint("  📦 Form data: \(bodyString.count) chars")
        
        // Простий аналіз креденшіалів
        if bodyString.contains("email") || bodyString.contains("password") || bodyString.contains("phone") {
            logPrint("  🎯 Potential credentials detected in form submission")
        }
    }
    
    private func handleDataImageURL(_ dataURL: String, in webView: WKWebView) {
        guard let image = ImageDataService.shared.imageFromDataURL(dataURL) else {
            logPrint("Failed to convert data URL to image")
            return
        }
        
        // Показуємо Share Sheet
        DispatchQueue.main.async {
            ImageDataService.shared.shareImage(image, from: webView)
        }
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
