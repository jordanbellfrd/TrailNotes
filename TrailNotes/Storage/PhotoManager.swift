import UIKit
import Combine

final class PhotoManager {
    static let shared = PhotoManager()

    private var photosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("TrailNotesPhotos")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 50
    }

    func savePhoto(_ image: UIImage) -> UUID {
        let id = UUID()
        if let data = image.jpegData(compressionQuality: 0.7) {
            let url = photosDirectory.appendingPathComponent(id.uuidString)
            try? data.write(to: url)
        }
        cache.setObject(image, forKey: id.uuidString as NSString)
        return id
    }

    func loadImage(_ id: UUID) -> UIImage? {
        let key = id.uuidString as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let url = photosDirectory.appendingPathComponent(id.uuidString)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    func deletePhoto(_ id: UUID) {
        cache.removeObject(forKey: id.uuidString as NSString)
        let url = photosDirectory.appendingPathComponent(id.uuidString)
        try? FileManager.default.removeItem(at: url)
    }

    func deletePhotos(_ ids: [UUID]) {
        ids.forEach { deletePhoto($0) }
    }
}
