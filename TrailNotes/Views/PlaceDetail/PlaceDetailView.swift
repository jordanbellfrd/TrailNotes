import SwiftUI
import MapKit
import Combine

struct PlaceDetailView: View {
    let placeID: UUID
    @EnvironmentObject var storage: LocalStorage
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var newNoteText = ""
    @State private var showAddNote = false

    private var place: Place? {
        storage.place(by: placeID)
    }

    var body: some View {
        if let place = place {
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        photoSection(place)
                        infoSection(place)
                        mapSection(place)
                        notesSection(place)
                        dangerZone
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 40)
                }

                CustomNavBar(
                    title: place.name,
                    showBack: true,
                    showSettings: false,
                    backAction: { dismiss() },
                    trailingItems: [
                        NavBarItem(icon: "pencil") { showEdit = true }
                    ]
                )
            }
            .fullScreenCover(isPresented: $showEdit) {
                PlaceEditView(mode: .edit(place))
            }
            .alert("Delete Place", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    storage.deletePlace(placeID)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure? This cannot be undone.")
            }
        } else {
            VStack {
                Text("Place not found")
                    .foregroundColor(AppTheme.secondaryText)
                Button("Close") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func photoSection(_ place: Place) -> some View {
        if !place.photoIDs.isEmpty {
            TabView {
                ForEach(place.photoIDs, id: \.self) { photoID in
                    if let image = PhotoManager.shared.loadImage(photoID) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 240)
                            .clipped()
                    }
                }
            }
            .tabViewStyle(.page)
            .frame(height: 240)
            .cornerRadius(AppTheme.cardCornerRadius)
            .padding(.horizontal, AppTheme.horizontalPadding)
        }
    }

    private func infoSection(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CategoryBadge(category: place.category)
                Spacer()
                Button {
                    storage.toggleFavorite(place.id)
                } label: {
                    Image(systemName: place.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundColor(place.isFavorite ? .red : AppTheme.secondaryText)
                }
            }

            if place.rating > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Want to return")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.secondaryText)
                    RatingDisplay(rating: place.rating)
                }
            }

            if !place.placeDescription.isEmpty {
                Text(place.placeDescription)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }

            if !place.bestSeasons.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Best Seasons")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryText)
                    HStack(spacing: 8) {
                        ForEach(place.bestSeasons) { season in
                            HStack(spacing: 4) {
                                Image(systemName: season.icon)
                                    .font(.system(size: 12))
                                Text(season.rawValue)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.accent.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
            }

            if let tripID = place.tripID, let trip = storage.trip(by: tripID) {
                HStack(spacing: 6) {
                    Image(systemName: "suitcase.fill")
                        .font(.system(size: 12))
                    Text(trip.name)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.accent.opacity(0.1))
                .cornerRadius(AppTheme.smallCornerRadius)
            }

            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11))
                Text(String(format: "%.4f, %.4f", place.latitude, place.longitude))
                    .font(.system(size: 12, design: .monospaced))
            }
            .foregroundColor(AppTheme.secondaryText)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cardCornerRadius)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, AppTheme.horizontalPadding)
    }

    private func mapSection(_ place: Place) -> some View {
        let coord = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        return Map(position: .constant(.region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))), interactionModes: []) {
            Marker(place.name, coordinate: coord)
                .tint(AppTheme.accent)
        }
        .frame(height: 160)
        .cornerRadius(AppTheme.cardCornerRadius)
        .padding(.horizontal, AppTheme.horizontalPadding)
    }

    private func notesSection(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Visit Notes")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    showAddNote.toggle()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.accent)
                }
            }

            if showAddNote {
                VStack(spacing: 8) {
                    TextEditor(text: $newNoteText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(AppTheme.warmGray.opacity(0.1))
                        .cornerRadius(AppTheme.smallCornerRadius)

                    HStack {
                        Spacer()
                        Button("Cancel") {
                            newNoteText = ""
                            showAddNote = false
                        }
                        .foregroundColor(AppTheme.secondaryText)

                        Button("Save") {
                            guard !newNoteText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            let note = PlaceNote(text: newNoteText)
                            storage.addNoteToPlace(placeID: place.id, note: note)
                            newNoteText = ""
                            showAddNote = false
                        }
                        .foregroundColor(AppTheme.accent)
                        .fontWeight(.semibold)
                    }
                    .font(.system(size: 14))
                }
            }

            if place.notes.isEmpty && !showAddNote {
                Text("No notes yet")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.secondaryText)
            } else {
                ForEach(place.notes.sorted(by: { $0.date > $1.date })) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.text)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                        Text(note.date, style: .date)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(AppTheme.warmGray.opacity(0.08))
                    .cornerRadius(AppTheme.smallCornerRadius)
                    .contextMenu {
                        Button(role: .destructive) {
                            storage.deleteNoteFromPlace(placeID: place.id, noteID: note.id)
                        } label: {
                            Label("Delete Note", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cardCornerRadius)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, AppTheme.horizontalPadding)
    }

    private var dangerZone: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Place")
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(AppTheme.destructive)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.destructive.opacity(0.08))
            .cornerRadius(AppTheme.cornerRadius)
        }
        .padding(.horizontal, AppTheme.horizontalPadding)
    }
}
