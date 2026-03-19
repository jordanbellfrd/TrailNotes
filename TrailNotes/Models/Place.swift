import Foundation

enum PlaceCategory: String, Codable, CaseIterable, Identifiable {
    case lake = "Lake"
    case forest = "Forest"
    case viewpoint = "Viewpoint"
    case restStop = "Rest Stop"
    case mountain = "Mountain"
    case camping = "Camping"
    case waterfall = "Waterfall"
    case historic = "Historic"
    case beach = "Beach"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .lake: return "drop.fill"
        case .forest: return "leaf.fill"
        case .viewpoint: return "binoculars.fill"
        case .restStop: return "cup.and.saucer.fill"
        case .mountain: return "mountain.2.fill"
        case .camping: return "tent.fill"
        case .waterfall: return "water.waves"
        case .historic: return "building.columns.fill"
        case .beach: return "sun.horizon.fill"
        case .other: return "mappin.circle.fill"
        }
    }
}

enum Season: String, Codable, CaseIterable, Identifiable {
    case spring = "Spring"
    case summer = "Summer"
    case autumn = "Autumn"
    case winter = "Winter"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .spring: return "leaf.arrow.circlepath"
        case .summer: return "sun.max.fill"
        case .autumn: return "wind"
        case .winter: return "snowflake"
        }
    }
}

struct PlaceNote: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var date: Date = Date()
}

struct Place: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String = ""
    var placeDescription: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var category: PlaceCategory = .other
    var photoIDs: [UUID] = []
    var rating: Int = 0
    var isFavorite: Bool = false
    var bestSeasons: [Season] = []
    var tripID: UUID? = nil
    var notes: [PlaceNote] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}
