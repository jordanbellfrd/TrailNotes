import SwiftUI
import Combine

struct ExploreView: View {
    @EnvironmentObject var storage: LocalStorage
    @EnvironmentObject var router: AppRouter
    @State private var searchText = ""
    @State private var selectedCategory: PlaceCategory? = nil

    private var filteredPlaces: [Place] {
        var results = storage.places
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.placeDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }
        return results.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            categoryFilter

            if filteredPlaces.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "leaf.fill",
                    title: "No Places Yet",
                    subtitle: "Start exploring and save beautiful places you discover.",
                    buttonTitle: "Add Place",
                    buttonAction: { router.showAddPlace = true }
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredPlaces) { place in
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

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.secondaryText)
            TextField("Search places...", text: $searchText)
                .font(.system(size: 15))
        }
        .padding(10)
        .background(AppTheme.warmGray.opacity(0.15))
        .cornerRadius(AppTheme.cornerRadius)
        .padding(.horizontal, AppTheme.horizontalPadding)
        .padding(.top, 4)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(PlaceCategory.allCases) { category in
                    filterChip(
                        title: category.rawValue,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.vertical, 10)
        }
    }

    private func filterChip(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : AppTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? AppTheme.accent : AppTheme.accent.opacity(0.1))
            .cornerRadius(20)
        }
    }
}
