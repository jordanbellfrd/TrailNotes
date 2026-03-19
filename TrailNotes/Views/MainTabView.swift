import SwiftUI
import Combine

struct MainTabView: View {
    @EnvironmentObject var storage: LocalStorage
    @StateObject private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            exploreTab
                .tabItem { Label("Explore", systemImage: "leaf.fill") }
                .tag(Tab.explore)

            mapTab
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(Tab.map)

            tripsTab
                .tabItem { Label("Trips", systemImage: "suitcase.fill") }
                .tag(Tab.trips)

            favoritesTab
                .tabItem { Label("Favorites", systemImage: "heart.fill") }
                .tag(Tab.favorites)

            profileTab
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(Tab.profile)
        }
        .tint(AppTheme.accent)
        .fullScreenCover(isPresented: $router.showSettings) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $router.showAddPlace) {
            PlaceEditView(mode: .add)
        }
        .fullScreenCover(isPresented: $router.showAddTrip) {
            TripEditView(mode: .add)
        }
        .fullScreenCover(item: $router.selectedPlaceID) { placeID in
            PlaceDetailView(placeID: placeID)
        }
        .fullScreenCover(item: $router.selectedTripID) { tripID in
            TripDetailView(tripID: tripID)
        }
        .fullScreenCover(isPresented: $router.editingProfile) {
            ProfileEditView()
        }
        .environmentObject(router)
    }

    // MARK: - Tab Wrappers

    private var exploreTab: some View {
        VStack(spacing: 0) {
            CustomNavBar(
                title: "Explore",
                showSettings: true,
                settingsAction: { router.showSettings = true },
                trailingItems: [NavBarItem(icon: "plus.circle.fill") { router.showAddPlace = true }]
            )
            ExploreView()
        }
        .background(AppTheme.background)
    }

    private var mapTab: some View {
        VStack(spacing: 0) {
            CustomNavBar(
                title: "Map",
                showSettings: true,
                settingsAction: { router.showSettings = true }
            )
            MapTabView()
        }
        .background(AppTheme.background)
    }

    private var tripsTab: some View {
        VStack(spacing: 0) {
            CustomNavBar(
                title: "Trips",
                showSettings: true,
                settingsAction: { router.showSettings = true },
                trailingItems: [NavBarItem(icon: "plus.circle.fill") { router.showAddTrip = true }]
            )
            TripsView()
        }
        .background(AppTheme.background)
    }

    private var favoritesTab: some View {
        VStack(spacing: 0) {
            CustomNavBar(
                title: "Favorites",
                showSettings: true,
                settingsAction: { router.showSettings = true }
            )
            FavoritesView()
        }
        .background(AppTheme.background)
    }

    private var profileTab: some View {
        VStack(spacing: 0) {
            CustomNavBar(
                title: "Profile",
                showSettings: true,
                settingsAction: { router.showSettings = true },
                trailingItems: [NavBarItem(icon: "pencil.circle.fill") { router.editingProfile = true }]
            )
            ProfileView()
        }
        .background(AppTheme.background)
    }
}

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
