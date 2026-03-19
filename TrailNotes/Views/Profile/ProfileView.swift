import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject var storage: LocalStorage
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader
                statsGrid
                recentActivity
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            if let avatarID = storage.profile.avatarPhotoID,
               let image = PhotoManager.shared.loadImage(avatarID) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.accent)
                    )
            }

            Text(storage.profile.name.isEmpty ? "Explorer" : storage.profile.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cardCornerRadius)
        .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCard(icon: "mappin.circle.fill", value: "\(storage.totalPlaces)", label: "Places")
            statCard(icon: "suitcase.fill", value: "\(storage.totalTrips)", label: "Trips")
            statCard(icon: "camera.fill", value: "\(storage.totalPhotos)", label: "Photos")
        }
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(AppTheme.accent)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cardCornerRadius)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Places")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            let recent = storage.places.sorted { $0.createdAt > $1.createdAt }.prefix(5)
            if recent.isEmpty {
                Text("No places added yet")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.secondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(recent)) { place in
                    Button {
                        router.selectedPlaceID = place.id
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: place.category.icon)
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 32, height: 32)
                                .background(AppTheme.accent.opacity(0.1))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.system(size: 14, weight: .medium))
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
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.cardCornerRadius)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
    }
}
