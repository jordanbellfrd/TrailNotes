import SwiftUI
import PhotosUI
import Combine

enum TripEditMode {
    case add
    case editTrip(Trip)
}

struct TripEditView: View {
    let mode: TripEditMode
    @EnvironmentObject var storage: LocalStorage
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var tripDescription: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var coverPhotoID: UUID? = nil
    @State private var selectedCoverItem: [PhotosPickerItem] = []

    private var isEditing: Bool {
        if case .editTrip = mode { return true }
        return false
    }

    init(mode: TripEditMode) {
        self.mode = mode
        if case .editTrip(let trip) = mode {
            _name = State(initialValue: trip.name)
            _tripDescription = State(initialValue: trip.tripDescription)
            _startDate = State(initialValue: trip.startDate)
            _endDate = State(initialValue: trip.endDate ?? Date())
            _hasEndDate = State(initialValue: trip.endDate != nil)
            _coverPhotoID = State(initialValue: trip.coverPhotoID)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    nameSection
                    descriptionSection
                    dateSection
                    coverSection
                    saveButton
                }
                .padding(.top, 56)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 40)
            }

            CustomNavBar(
                title: isEditing ? "Edit Trip" : "New Trip",
                showBack: true,
                showSettings: false,
                backAction: { dismiss() }
            )
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Name")
            TextField("Trip name", text: $name)
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
            TextEditor(text: $tripDescription)
                .scrollContentBackground(.hidden)
                .font(.system(size: 15))
                .frame(minHeight: 80)
                .padding(8)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadius)
                .shadow(color: AppTheme.cardShadow, radius: 2)
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Dates")

            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                .font(.system(size: 15))
                .tint(AppTheme.accent)

            Toggle("Has End Date", isOn: $hasEndDate)
                .font(.system(size: 15))
                .tint(AppTheme.accent)

            if hasEndDate {
                DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .font(.system(size: 15))
                    .tint(AppTheme.accent)
            }
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: AppTheme.cardShadow, radius: 2)
    }

    private var coverSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Cover Photo")

            if let coverID = coverPhotoID,
               let image = PhotoManager.shared.loadImage(coverID) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(AppTheme.cornerRadius)

                    Button {
                        PhotoManager.shared.deletePhoto(coverID)
                        coverPhotoID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            }

            PhotosPicker(selection: $selectedCoverItem, maxSelectionCount: 1, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 15, weight: .medium))
                    Text(coverPhotoID == nil ? "Add Cover" : "Change Cover")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.accent.opacity(0.12))
                .cornerRadius(AppTheme.smallCornerRadius)
            }
            .onChange(of: selectedCoverItem) { _, items in
                guard let item = items.first else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            if let oldID = coverPhotoID {
                                PhotoManager.shared.deletePhoto(oldID)
                            }
                            coverPhotoID = PhotoManager.shared.savePhoto(image)
                            selectedCoverItem = []
                        }
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            saveTrip()
        } label: {
            Text(isEditing ? "Save Changes" : "Create Trip")
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

    private func saveTrip() {
        if case .editTrip(let existing) = mode {
            var updated = existing
            updated.name = name
            updated.tripDescription = tripDescription
            updated.startDate = startDate
            updated.endDate = hasEndDate ? endDate : nil
            updated.coverPhotoID = coverPhotoID
            updated.updatedAt = Date()
            storage.updateTrip(updated)
        } else {
            var trip = Trip()
            trip.name = name
            trip.tripDescription = tripDescription
            trip.startDate = startDate
            trip.endDate = hasEndDate ? endDate : nil
            trip.coverPhotoID = coverPhotoID
            storage.addTrip(trip)
        }
        dismiss()
    }
}
