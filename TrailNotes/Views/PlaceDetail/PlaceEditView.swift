import SwiftUI
import Combine

enum EditMode {
    case add
    case edit(Place)
}

struct PlaceEditView: View {
    let mode: EditMode
    @EnvironmentObject var storage: LocalStorage
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var placeDescription: String = ""
    @State private var category: PlaceCategory = .other
    @State private var rating: Int = 0
    @State private var isFavorite: Bool = false
    @State private var bestSeasons: Set<Season> = []
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var photoIDs: [UUID] = []
    @State private var tripID: UUID? = nil
    @State private var showMapPicker = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingPlace: Place? {
        if case .edit(let place) = mode { return place }
        return nil
    }

    init(mode: EditMode) {
        self.mode = mode
        if case .edit(let place) = mode {
            _name = State(initialValue: place.name)
            _placeDescription = State(initialValue: place.placeDescription)
            _category = State(initialValue: place.category)
            _rating = State(initialValue: place.rating)
            _isFavorite = State(initialValue: place.isFavorite)
            _bestSeasons = State(initialValue: Set(place.bestSeasons))
            _latitude = State(initialValue: place.latitude)
            _longitude = State(initialValue: place.longitude)
            _photoIDs = State(initialValue: place.photoIDs)
            _tripID = State(initialValue: place.tripID)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameSection
                    descriptionSection
                    categorySection
                    ratingSection
                    seasonSection
                    locationSection
                    photoSection
                    tripSection
                    saveButton
                }
                .padding(.top, 56)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 40)
            }

            CustomNavBar(
                title: isEditing ? "Edit Place" : "New Place",
                showBack: true,
                showSettings: false,
                backAction: { dismiss() }
            )
        }
        .fullScreenCover(isPresented: $showMapPicker) {
            MapPickerView(latitude: $latitude, longitude: $longitude) {
                showMapPicker = false
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Name")
            TextField("Place name", text: $name)
                .font(.system(size: 16))
                .padding(12)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadius)
                .shadow(color: AppTheme.cardShadow, radius: 2)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Description")
            TextEditor(text: $placeDescription)
                .scrollContentBackground(.hidden)
                .font(.system(size: 15))
                .frame(minHeight: 80)
                .padding(8)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadius)
                .shadow(color: AppTheme.cardShadow, radius: 2)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Category")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlaceCategory.allCases) { cat in
                        Button {
                            category = cat
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 12))
                                Text(cat.rawValue)
                                    .font(.system(size: 13, weight: category == cat ? .semibold : .regular))
                            }
                            .foregroundColor(category == cat ? .white : AppTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(category == cat ? AppTheme.accent : AppTheme.accent.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                }
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Want to Return")
            RatingPicker(rating: $rating)
        }
    }

    private var seasonSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Best Seasons")
            HStack(spacing: 8) {
                ForEach(Season.allCases) { season in
                    Button {
                        if bestSeasons.contains(season) {
                            bestSeasons.remove(season)
                        } else {
                            bestSeasons.insert(season)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: season.icon)
                                .font(.system(size: 12))
                            Text(season.rawValue)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(bestSeasons.contains(season) ? .white : AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(bestSeasons.contains(season) ? AppTheme.accent : AppTheme.accent.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Location")
            Button {
                showMapPicker = true
            } label: {
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(AppTheme.accent)
                    if latitude != 0 || longitude != 0 {
                        Text(String(format: "%.4f, %.4f", latitude, longitude))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.primary)
                    } else {
                        Text("Pick on map")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.secondaryText)
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadius)
                .shadow(color: AppTheme.cardShadow, radius: 2)
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Photos")
            if !photoIDs.isEmpty {
                PhotoGridView(photoIDs: photoIDs, onDelete: { id in
                    PhotoManager.shared.deletePhoto(id)
                    photoIDs.removeAll { $0 == id }
                }, editable: true)
            }
            PhotoPickerButton(maxSelection: 10) { images in
                for image in images {
                    let id = PhotoManager.shared.savePhoto(image)
                    photoIDs.append(id)
                }
            }
        }
    }

    private var tripSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Trip")
            if storage.trips.isEmpty {
                Text("No trips created yet")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            tripID = nil
                        } label: {
                            Text("None")
                                .font(.system(size: 13, weight: tripID == nil ? .semibold : .regular))
                                .foregroundColor(tripID == nil ? .white : AppTheme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(tripID == nil ? AppTheme.accent : AppTheme.accent.opacity(0.1))
                                .cornerRadius(16)
                        }
                        ForEach(storage.trips) { trip in
                            Button {
                                tripID = trip.id
                            } label: {
                                Text(trip.name)
                                    .font(.system(size: 13, weight: tripID == trip.id ? .semibold : .regular))
                                    .foregroundColor(tripID == trip.id ? .white : AppTheme.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(tripID == trip.id ? AppTheme.accent : AppTheme.accent.opacity(0.1))
                                    .cornerRadius(16)
                            }
                        }
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            savePlace()
        } label: {
            Text(isEditing ? "Save Changes" : "Add Place")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(name.isEmpty ? AppTheme.secondaryText : AppTheme.accent)
                .cornerRadius(AppTheme.cornerRadius)
        }
        .disabled(name.isEmpty)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(AppTheme.secondaryText)
            .textCase(.uppercase)
    }

    private func savePlace() {
        if case .edit(let existing) = mode {
            var updated = existing
            updated.name = name
            updated.placeDescription = placeDescription
            updated.category = category
            updated.rating = rating
            updated.isFavorite = isFavorite
            updated.bestSeasons = Array(bestSeasons)
            updated.latitude = latitude
            updated.longitude = longitude
            updated.photoIDs = photoIDs
            updated.tripID = tripID
            updated.updatedAt = Date()
            storage.updatePlace(updated)
        } else {
            var place = Place()
            place.name = name
            place.placeDescription = placeDescription
            place.category = category
            place.rating = rating
            place.isFavorite = isFavorite
            place.bestSeasons = Array(bestSeasons)
            place.latitude = latitude
            place.longitude = longitude
            place.photoIDs = photoIDs
            place.tripID = tripID
            storage.addPlace(place)

            if let tid = tripID {
                storage.addPlaceToTrip(placeID: place.id, tripID: tid)
            }
        }
        dismiss()
    }
}
