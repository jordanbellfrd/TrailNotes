import Foundation
import Combine

final class LocalStorage: ObservableObject {
    @Published var places: [Place] = [] { didSet { save(places, key: "places") } }
    @Published var trips: [Trip] = [] { didSet { save(trips, key: "trips") } }
    @Published var profile: UserProfile = UserProfile() { didSet { save(profile, key: "profile") } }
    @Published var settings: AppSettings = AppSettings() { didSet { save(settings, key: "settings") } }
    @Published var hasCompletedOnboarding: Bool = false {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    init() {
        places = load(key: "places", type: [Place].self) ?? []
        trips = load(key: "trips", type: [Trip].self) ?? []
        profile = load(key: "profile", type: UserProfile.self) ?? UserProfile()
        settings = load(key: "settings", type: AppSettings.self) ?? AppSettings()
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Place CRUD

    func addPlace(_ place: Place) {
        places.append(place)
    }

    func updatePlace(_ place: Place) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[index] = place
    }

    func deletePlace(_ id: UUID) {
        if let place = places.first(where: { $0.id == id }) {
            PhotoManager.shared.deletePhotos(place.photoIDs)
        }
        places.removeAll { $0.id == id }
        for i in trips.indices {
            trips[i].placeIDs.removeAll { $0 == id }
        }
    }

    func place(by id: UUID) -> Place? {
        places.first { $0.id == id }
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = places.firstIndex(where: { $0.id == id }) else { return }
        places[index].isFavorite.toggle()
    }

    // MARK: - Trip CRUD

    func addTrip(_ trip: Trip) {
        trips.append(trip)
    }

    func updateTrip(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index] = trip
    }

    func deleteTrip(_ id: UUID) {
        if let trip = trips.first(where: { $0.id == id }) {
            if let coverID = trip.coverPhotoID {
                PhotoManager.shared.deletePhoto(coverID)
            }
        }
        for i in places.indices {
            if places[i].tripID == id {
                places[i].tripID = nil
            }
        }
        trips.removeAll { $0.id == id }
    }

    func trip(by id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }

    func placesForTrip(_ tripID: UUID) -> [Place] {
        places.filter { $0.tripID == tripID }
    }

    func addPlaceToTrip(placeID: UUID, tripID: UUID) {
        guard let pi = places.firstIndex(where: { $0.id == placeID }),
              let ti = trips.firstIndex(where: { $0.id == tripID }) else { return }
        places[pi].tripID = tripID
        if !trips[ti].placeIDs.contains(placeID) {
            trips[ti].placeIDs.append(placeID)
        }
    }

    func removePlaceFromTrip(placeID: UUID, tripID: UUID) {
        guard let pi = places.firstIndex(where: { $0.id == placeID }),
              let ti = trips.firstIndex(where: { $0.id == tripID }) else { return }
        places[pi].tripID = nil
        trips[ti].placeIDs.removeAll { $0 == placeID }
    }

    // MARK: - Place Notes

    func addNoteToPlace(placeID: UUID, note: PlaceNote) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        places[index].notes.append(note)
    }

    func deleteNoteFromPlace(placeID: UUID, noteID: UUID) {
        guard let index = places.firstIndex(where: { $0.id == placeID }) else { return }
        places[index].notes.removeAll { $0.id == noteID }
    }

    // MARK: - Profile

    func updateProfile(_ profile: UserProfile) {
        self.profile = profile
    }

    // MARK: - Stats

    var totalPlaces: Int { places.count }
    var totalTrips: Int { trips.count }
    var totalPhotos: Int { places.reduce(0) { $0 + $1.photoIDs.count } }
    var favoritePlaces: [Place] { places.filter { $0.isFavorite } }

    // MARK: - Data Management

    func resetAllData() {
        for place in places {
            PhotoManager.shared.deletePhotos(place.photoIDs)
        }
        for trip in trips {
            if let coverID = trip.coverPhotoID {
                PhotoManager.shared.deletePhoto(coverID)
            }
        }
        if let avatarID = profile.avatarPhotoID {
            PhotoManager.shared.deletePhoto(avatarID)
        }
        places = []
        trips = []
        profile = UserProfile()
        settings = AppSettings()
        hasCompletedOnboarding = false
    }

    func exportJSON() -> Data? {
        struct ExportData: Codable {
            let places: [Place]
            let trips: [Trip]
            let profile: UserProfile
        }
        let export = ExportData(places: places, trips: trips, profile: profile)
        return try? JSONEncoder().encode(export)
    }

    // MARK: - Persistence

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(key: String, type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
