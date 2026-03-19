import Foundation

enum DistanceUnit: String, Codable, CaseIterable {
    case kilometers = "Kilometers"
    case miles = "Miles"
}

enum MapDisplayStyle: String, Codable, CaseIterable {
    case standard = "Standard"
    case satellite = "Satellite"
    case hybrid = "Hybrid"
}

struct AppSettings: Codable {
    var distanceUnit: DistanceUnit = .kilometers
    var mapDisplayStyle: MapDisplayStyle = .standard
    var accentColorName: String = "trailGreen"
}
