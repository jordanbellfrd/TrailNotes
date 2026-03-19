import SwiftUI
import Combine

struct FavoritesView: View {
    @EnvironmentObject var storage: LocalStorage
    @EnvironmentObject var router: AppRouter
    @State private var sortByRating = false

    private var favorites: [Place] {
        let faves = storage.favoritePlaces
        if sortByRating {
            return faves.sorted { $0.rating > $1.rating }
        }
        return faves.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !storage.favoritePlaces.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        withAnimation { sortByRating.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: sortByRating ? "star.fill" : "clock")
                                .font(.system(size: 12))
                            Text(sortByRating ? "By Rating" : "Recent")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(AppTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 8)
            }

            if favorites.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "heart.fill",
                    title: "No Favorites",
                    subtitle: "Tap the heart icon on places you love to see them here."
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(favorites) { place in
                            PlaceCardView(
                                place: place,
                                onTap: { router.selectedPlaceID = place.id },
                                onFavorite: { storage.toggleFavorite(place.id) }
                            )
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}
