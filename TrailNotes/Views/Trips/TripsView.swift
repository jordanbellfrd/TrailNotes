import SwiftUI
import Combine

struct TripsView: View {
    @EnvironmentObject var storage: LocalStorage
    @EnvironmentObject var router: AppRouter

    private var sortedTrips: [Trip] {
        storage.trips.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        if sortedTrips.isEmpty {
            VStack {
                Spacer()
                EmptyStateView(
                    icon: "suitcase.fill",
                    title: "No Trips Yet",
                    subtitle: "Group your places into trips to organize your adventures.",
                    buttonTitle: "Create Trip",
                    buttonAction: { router.showAddTrip = true }
                )
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sortedTrips) { trip in
                        TripCardView(trip: trip) {
                            router.selectedTripID = trip.id
                        }
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
    }
}

struct TripCardView: View {
    let trip: Trip
    var onTap: () -> Void
    @EnvironmentObject var storage: LocalStorage

    private var placeCount: Int {
        storage.placesForTrip(trip.id).count
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                if let coverID = trip.coverPhotoID,
                   let image = PhotoManager.shared.loadImage(coverID) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(AppTheme.accentLight.opacity(0.2))
                        .frame(height: 140)
                        .overlay(
                            Image(systemName: "suitcase.fill")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.warmGray)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(trip.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Label(dateRange, systemImage: "calendar")
                        Label("\(placeCount) places", systemImage: "mappin.and.ellipse")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.secondaryText)

                    if !trip.tripDescription.isEmpty {
                        Text(trip.tripDescription)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.secondaryText)
                            .lineLimit(2)
                    }
                }
                .padding(12)
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cardCornerRadius)
            .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let start = formatter.string(from: trip.startDate)
        if let end = trip.endDate {
            return "\(start) - \(formatter.string(from: end))"
        }
        return start
    }
}
