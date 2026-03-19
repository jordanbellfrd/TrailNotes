import SwiftUI
import MapKit
import Combine

struct MapTabView: View {
    @EnvironmentObject var storage: LocalStorage
    @EnvironmentObject var router: AppRouter
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                ForEach(storage.places) { place in
                    Annotation(place.name, coordinate: CLLocationCoordinate2D(
                        latitude: place.latitude,
                        longitude: place.longitude
                    )) {
                        Button {
                            router.selectedPlaceID = place.id
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: place.category.icon)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        place.isFavorite ? Color.orange : AppTheme.accent
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 3)

                                Text(place.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .mapStyle(currentMapStyle)

            VStack(spacing: 12) {
                Button {
                    router.showAddPlace = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.accent)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.cardShadow, radius: 6)
                }

                Button {
                    withAnimation {
                        cameraPosition = .automatic
                    }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.cardBackground)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.cardShadow, radius: 4)
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 20)
        }
    }

    private var currentMapStyle: _MapKit_SwiftUI.MapStyle {
        switch storage.settings.mapDisplayStyle {
        case .standard: return .standard
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        }
    }
}
