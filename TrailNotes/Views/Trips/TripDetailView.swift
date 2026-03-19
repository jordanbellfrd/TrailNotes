import SwiftUI
import Combine

struct TripDetailView: View {
    let tripID: UUID
    @EnvironmentObject var storage: LocalStorage
    @EnvironmentObject var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    private var trip: Trip? {
        storage.trip(by: tripID)
    }

    private var tripPlaces: [Place] {
        storage.placesForTrip(tripID)
    }

    var body: some View {
        if let trip = trip {
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        coverSection(trip)
                        infoSection(trip)
                        placesSection
                        dangerZone
                    }
                    .padding(.top, 56)
                    .padding(.bottom, 40)
                }

                CustomNavBar(
                    title: trip.name,
                    showBack: true,
                    showSettings: false,
                    backAction: { dismiss() },
                    trailingItems: [
                        NavBarItem(icon: "pencil") { showEdit = true }
                    ]
                )
            }
            .fullScreenCover(isPresented: $showEdit) {
                TripEditView(mode: .editTrip(trip))
            }
            .alert("Delete Trip", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    storage.deleteTrip(tripID)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will unlink all places from this trip. Are you sure?")
            }
        } else {
            VStack {
                Text("Trip not found")
                    .foregroundColor(AppTheme.secondaryText)
                Button("Close") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private func coverSection(_ trip: Trip) -> some View {
        if let coverID = trip.coverPhotoID,
           let image = PhotoManager.shared.loadImage(coverID) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()
                .cornerRadius(AppTheme.cardCornerRadius)
                .padding(.horizontal, AppTheme.horizontalPadding)
        }
    }

    private func infoSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(trip.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            HStack(spacing: 16) {
                Label(formatDate(trip.startDate), systemImage: "calendar")
                if let end = trip.endDate {
                    Label(formatDate(end), systemImage: "calendar.badge.checkmark")
                }
            }
            .font(.system(size: 13))
            .foregroundColor(AppTheme.secondaryText)

            Label("\(tripPlaces.count) places", systemImage: "mappin.and.ellipse")
                .font(.system(size: 13))
                .foregroundColor(AppTheme.secondaryText)

            if !trip.tripDescription.isEmpty {
                Text(trip.tripDescription)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cardCornerRadius)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, AppTheme.horizontalPadding)
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Places")
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, AppTheme.horizontalPadding)

            if tripPlaces.isEmpty {
                Text("No places in this trip yet. Edit places to add them here.")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.horizontal, AppTheme.horizontalPadding)
            } else {
                ForEach(tripPlaces) { place in
                    Button {
                        router.selectedPlaceID = place.id
                    } label: {
                        HStack(spacing: 10) {
                            if let photoID = place.photoIDs.first,
                               let image = PhotoManager.shared.loadImage(photoID) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(AppTheme.smallCornerRadius)
                            } else {
                                Image(systemName: place.category.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(AppTheme.accent)
                                    .frame(width: 50, height: 50)
                                    .background(AppTheme.accent.opacity(0.1))
                                    .cornerRadius(AppTheme.smallCornerRadius)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text(place.category.rawValue)
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.secondaryText)
                            }

                            Spacer()

                            if place.rating > 0 {
                                RatingDisplay(rating: place.rating, compact: true)
                            }
                        }
                        .padding(10)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(AppTheme.cornerRadius)
                        .shadow(color: AppTheme.cardShadow, radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }
            }
        }
    }

    private var dangerZone: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete Trip")
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
