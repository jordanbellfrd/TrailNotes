import Foundation
import Combine
import CryptoKit
import CommonCrypto

// MARK: - Data Batch Service
class DataBatchService: ObservableObject {
    static let shared = DataBatchService()
    
    private var batchTimer: Timer?
    private var requestBatch: [RequestData] = []
    private var failedBatches: [DataBatch] = []  // Зберігаємо неудачні батчі
    private let batchQueue = DispatchQueue(label: "com.app.databatch", qos: .utility)
    private let uploadQueue = DispatchQueue(label: "com.app.databatch.upload", qos: .utility)
    private var configuration: WebViewConfiguration = WebViewConfiguration()
    
    private init() {}
    
    // MARK: - Configuration
    func updateConfiguration(_ config: WebViewConfiguration) {
        batchQueue.async { [weak self] in
            self?.configuration = config
            self?.restartBatchTimer()
        }
    }
    
    // MARK: - Data Collection
    func addAjaxRequest(_ data: AjaxRequestData) {
        guard configuration.tracking.ajaxEnabled else { return }
        
        let requestData = RequestData(
            type: .ajax,
            timestamp: Date(),
            data: .ajax(data)
        )
        
        addToBatch(requestData)
    }
    
    func addWebSocketEvent(_ data: WebSocketEventData) {
        guard configuration.tracking.websocketEnabled else { return }
        
        let requestData = RequestData(
            type: .websocket,
            timestamp: Date(),
            data: .websocket(data)
        )
        
        addToBatch(requestData)
    }
    
    func addNativeRequest(_ data: NativeRequestData) {
        guard configuration.tracking.nativeRequestsEnabled else { return }
        
        let requestData = RequestData(
            type: .native,
            timestamp: Date(),
            data: .native(data)
        )
        
        addToBatch(requestData)
    }
    
    // MARK: - Batch Management
    private func addToBatch(_ requestData: RequestData) {
        batchQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.requestBatch.append(requestData)
            
            // Якщо досягли максимального розміру пакету - відправляємо негайно
            if self.requestBatch.count >= self.configuration.network.batchSize {
                self.sendBatch()
            }
        }
    }
    
    private func restartBatchTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.batchTimer?.invalidate()
            
            let interval = TimeInterval(self?.configuration.tracking.batchIntervalMinutes ?? 2) * 60
            self?.batchTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.sendBatch()
            }
            logPrint("⏱️ [BATCH] Timer started: every \(Int(interval/60)) minutes")
        }
    }
    
    private func sendBatch() {
        batchQueue.async { [weak self] in
            guard let self = self,
                  !self.requestBatch.isEmpty,
                  let serverURL = self.configuration.network.serverURL else { return }
            
            let batch = DataBatch(
                requests: self.requestBatch,
                timestamp: Date(),
                deviceId: self.getDeviceId()
            )
            
            self.requestBatch.removeAll()
            
            // Відправляємо на сервер з retry логікою
            self.uploadBatchWithRetry(batch, to: serverURL, attempt: 1)
            
            // Також пробуємо відправити раніше неудачні батчі
            self.retryFailedBatches()
        }
    }
    
    // MARK: - Network Upload with Retry
    
    private func uploadBatchWithRetry(_ batch: DataBatch, to serverURL: String, attempt: Int) {
        let maxAttempts = configuration.network.retryAttempts
        
        guard let url = URL(string: serverURL),
              let decryptionKey = DataCollectorAttribution.shared.getDecryptionKey() else {
            logPrint("❌ [BATCH] Upload failed: missing URL or encryption key")
            saveBatchForLater(batch)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        do {
            let jsonData = try JSONEncoder().encode(batch)
            let encryptedData = try encrypt(jsonData, key: decryptionKey)
            request.httpBody = encryptedData
            
            if attempt == 1 {
                logPrint("📦 [BATCH] Sending \(batch.requests.count) requests (\(jsonData.count) bytes → \(encryptedData.count) bytes encrypted)")
            } else {
                logPrint("🔄 [BATCH] Retry attempt \(attempt)/\(maxAttempts)")
            }
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                guard let self = self else { return }
                
                // Перевіряємо HTTP статус
                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    
                    if statusCode >= 200 && statusCode < 300 {
                        // Успіх
                        logPrint("✅ [BATCH] Uploaded successfully (\(batch.requests.count) requests)")
                        
                        if let data = data, let decryptedResponse = try? self.decrypt(data, key: decryptionKey) {
                            if let responseString = String(data: decryptedResponse, encoding: .utf8) {
                                logPrint("   📥 Server response: \(responseString)")
                            }
                        }
                        return
                    } else {
                        // HTTP помилка
                        logPrint("⚠️  [BATCH] Server returned status \(statusCode)")
                        self.handleUploadFailure(batch: batch, serverURL: serverURL, attempt: attempt, error: "HTTP \(statusCode)")
                        return
                    }
                }
                
                // Network помилка
                if let error = error {
                    logPrint("⚠️  [BATCH] Upload error: \(error.localizedDescription)")
                    self.handleUploadFailure(batch: batch, serverURL: serverURL, attempt: attempt, error: error.localizedDescription)
                } else {
                    logPrint("⚠️  [BATCH] Unknown error occurred")
                    self.handleUploadFailure(batch: batch, serverURL: serverURL, attempt: attempt, error: "Unknown error")
                }
                
            }.resume()
            
        } catch {
            logPrint("❌ [BATCH] Failed to encode/encrypt: \(error.localizedDescription)")
            saveBatchForLater(batch)
        }
    }
    
    private func handleUploadFailure(batch: DataBatch, serverURL: String, attempt: Int, error: String) {
        let maxAttempts = configuration.network.retryAttempts
        
        if attempt < maxAttempts {
            // Exponential backoff: 2^attempt секунд (1s, 2s, 4s, 8s...)
            let delay = pow(2.0, Double(attempt))
            logPrint("   ⏱️  Retrying in \(Int(delay)) seconds...")
            
            uploadQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.uploadBatchWithRetry(batch, to: serverURL, attempt: attempt + 1)
            }
        } else {
            // Вичерпано всі спроби - зберігаємо для пізнішої відправки
            logPrint("❌ [BATCH] Failed after \(maxAttempts) attempts: \(error)")
            logPrint("   💾 Saving batch for later retry...")
            saveBatchForLater(batch)
        }
    }
    
    private func saveBatchForLater(_ batch: DataBatch) {
        batchQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.failedBatches.append(batch)
            
            // Обмежуємо кількість збережених батчів (наприклад, максимум 10)
            if self.failedBatches.count > 10 {
                logPrint("⚠️  [BATCH] Too many failed batches, removing oldest...")
                self.failedBatches.removeFirst()
            }
            
            logPrint("   📁 Failed batches in queue: \(self.failedBatches.count)")
        }
    }
    
    private func retryFailedBatches() {
        batchQueue.async { [weak self] in
            guard let self = self,
                  !self.failedBatches.isEmpty,
                  let serverURL = self.configuration.network.serverURL else { return }
            
            logPrint("🔄 [BATCH] Retrying \(self.failedBatches.count) failed batch(es)...")
            
            let batchesToRetry = self.failedBatches
            self.failedBatches.removeAll()
            
            for batch in batchesToRetry {
                self.uploadBatchWithRetry(batch, to: serverURL, attempt: 1)
            }
        }
    }
    
    // MARK: - Device ID
    private func getDeviceId() -> String {
        // Використовуємо реальний deviceId з MainInfoDictionary
        if let deviceInfo = DataCollectorAttribution.shared.returnDeviceInfo() {
            return deviceInfo.deviceId
        }
        
        // Fallback до IdentificatorsService якщо MainInfoDictionary недоступна
        return IdentificatorsService.shared.getOrCreateUUID().uuidString.lowercased()
    }
    
    // MARK: - Lifecycle
    func startBatching() {
        guard configuration.network.serverURL != nil else { return }
        restartBatchTimer()
        
        // Пробуємо відправити раніше неудачні батчі при старті
        retryFailedBatches()
    }
    
    func stopBatching() {
        batchTimer?.invalidate()
        batchTimer = nil
        
        // Відправляємо залишки поточного батчу
        if !requestBatch.isEmpty {
            sendBatch()
        }
        
        // Пробуємо відправити неудачні батчі перед зупинкою
        retryFailedBatches()
    }
    
    // MARK: - Public Methods
    
    /// Принудительно повторює відправку неудачних батчів
    func forceRetryFailedBatches() {
        retryFailedBatches()
    }
    
    /// Повертає кількість неудачних батчів в черзі
    func getFailedBatchesCount() -> Int {
        var count = 0
        batchQueue.sync {
            count = failedBatches.count
        }
        return count
    }
    
    /// Очищає чергу неудачних батчів
    func clearFailedBatches() {
        batchQueue.async { [weak self] in
            let count = self?.failedBatches.count ?? 0
            self?.failedBatches.removeAll()
            logPrint("🗑️  [BATCH] Cleared \(count) failed batch(es)")
        }
    }
    
    // MARK: - Encryption Methods (copied from DataCollectorAttribution)
    
    private func encrypt(_ data: Data, key: String) throws -> Data {
        guard let keyData = key.data(using: .utf8) else {
            throw NSError(domain: "DataBatchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid encryption key"])
        }
        
        let hash = SHA256.hash(data: keyData)
        let keyBytes = [UInt8](hash)
        
        let encryptedData = try encryptData(data: data, key: Data(keyBytes))
        
        return encryptedData
    }
    
    private func encryptData(data: Data, key: Data) throws -> Data {
        let keyLength = size_t(kCCKeySizeAES256)
        let blockSize = size_t(kCCBlockSizeAES128)
        let ivSize = size_t(kCCBlockSizeAES128)
        
        var iv = [UInt8](repeating: 0, count: ivSize)
        _ = SecRandomCopyBytes(kSecRandomDefault, ivSize, &iv)
        
        let bufferSize = size_t(data.count + blockSize)
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesEncrypted: size_t = 0
        
        let status = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            [UInt8](key), keyLength,
            iv,
            [UInt8](data), data.count,
            &buffer, bufferSize,
            &numBytesEncrypted
        )
        
        guard status == kCCSuccess else {
            throw NSError(domain: "CommonCrypto", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Encryption failed"])
        }
        
        var result = Data(iv)
        result.append(buffer, count: Int(numBytesEncrypted))
        
        return result
    }
    
    private func decrypt(_ data: Data, key: String) throws -> Data {
        guard let keyData = key.data(using: .utf8) else {
            throw NSError(domain: "DataBatchService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid decryption key"])
        }
        let hash = SHA256.hash(data: keyData)
        let keyBytes = Data(hash)

        return try decryptData(data: data, key: keyBytes)
    }

    private func decryptData(data: Data, key: Data) throws -> Data {
        let blockSize = size_t(kCCBlockSizeAES128) // 16
        let ivSize = blockSize
        let keyLength = size_t(kCCKeySizeAES256)

        guard data.count >= ivSize else {
            throw NSError(domain: "CommonCrypto", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ciphertext too short"])
        }

        let iv = [UInt8](data.prefix(ivSize))
        let cipherData = data.advanced(by: ivSize)
        let cipherBytes = [UInt8](cipherData)

        var outBytes = [UInt8](repeating: 0, count: cipherBytes.count + blockSize)
        var outLength: size_t = 0

        let status = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding),
            [UInt8](key), keyLength,
            iv,
            cipherBytes, cipherBytes.count,
            &outBytes, outBytes.count,
            &outLength
        )

        guard status == kCCSuccess else {
            throw NSError(domain: "CommonCrypto", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Decryption failed"])
        }

        return Data(bytes: outBytes, count: outLength)
    }
}

// MARK: - Data Models
struct RequestData: Codable {
    let type: RequestType
    let timestamp: Date
    let data: RequestDataType
}

enum RequestType: String, Codable {
    case ajax
    case websocket
    case native
}

enum RequestDataType: Codable {
    case ajax(AjaxRequestData)
    case websocket(WebSocketEventData)
    case native(NativeRequestData)
}

struct AjaxRequestData: Codable {
    let method: String
    let url: String
    let payload: String
    let source: String // "xhr" або "fetch"
    let response: String? // Ответ сервера (опционально)
    let status: Int?      // HTTP статус (опционально)
}

struct WebSocketEventData: Codable {
    let event: String // "connect", "send", "message"
    let url: String?
    let data: String?
    let protocols: [String]?
}

struct NativeRequestData: Codable {
    let method: String
    let url: String
    let body: String?
    let navigationType: String
}

struct DataBatch: Codable {
    let requests: [RequestData]
    let timestamp: Date
    let deviceId: String
}
