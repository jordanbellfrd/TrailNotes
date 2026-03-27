import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    let domain: String = "https://pathlog.fun"

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }
        NSLog("\(request.content.userInfo)")
        if let pushId = request.content.userInfo["pushId"] as? String {
                sendDeliveredEvent(pushId: pushId)
        }

        if let mediaUrlString = request.content.userInfo["media-url"] as? String,
           let mediaUrl = URL(string: mediaUrlString) {

            downloadImage(from: mediaUrl) { attachment in
                if let attachment = attachment {
                    bestAttemptContent.attachments = [attachment]
                }
                contentHandler(bestAttemptContent)
            }

        } else {
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func downloadImage(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { downloadURL, response, error in
            guard let downloadURL = downloadURL else {
                completion(nil)
                return
            }

            let fileManager = FileManager.default
            let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            let uniqueURL = tmpDir.appendingPathComponent(UUID().uuidString + ".jpg")

            do {
                try fileManager.moveItem(at: downloadURL, to: uniqueURL)
                let attachment = try UNNotificationAttachment(identifier: "image", url: uniqueURL, options: nil)
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }

    private func sendDeliveredEvent(pushId: String) {
            let urlString = "\(domain)/push-event/\(pushId)/delivered"
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    return
                }

                if let responseString = String(data: data ?? Data(), encoding: .utf8) {
                }

                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                }
            }
            task.resume()
        }
}
