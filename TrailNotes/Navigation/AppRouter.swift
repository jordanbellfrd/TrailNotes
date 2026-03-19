import SwiftUI
import Combine

enum Tab: String, CaseIterable {
    case explore = "Explore"
    case map = "Map"
    case trips = "Trips"
    case favorites = "Favorites"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .explore: return "leaf.fill"
        case .map: return "map.fill"
        case .trips: return "suitcase.fill"
        case .favorites: return "heart.fill"
        case .profile: return "person.fill"
        }
    }
}

final class AppRouter: ObservableObject {
    @Published var selectedTab: Tab = .explore
    @Published var showSettings = false
    @Published var showAddPlace = false
    @Published var showAddTrip = false
    @Published var selectedPlaceID: UUID? = nil
    @Published var selectedTripID: UUID? = nil
    @Published var editingPlaceID: UUID? = nil
    @Published var editingTripID: UUID? = nil
    @Published var editingProfile = false

    var tabTitle: String { selectedTab.rawValue }
}
