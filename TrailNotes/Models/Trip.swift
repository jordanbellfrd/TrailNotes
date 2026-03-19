import Foundation

struct Trip: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String = ""
    var tripDescription: String = ""
    var startDate: Date = Date()
    var endDate: Date? = nil
    var coverPhotoID: UUID? = nil
    var placeIDs: [UUID] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
