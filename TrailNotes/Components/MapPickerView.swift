import SwiftUI
import MapKit
import Combine

struct MapPickerView: View {
    @Binding var latitude: Double
    @Binding var longitude: Double
    var onDone: () -> Void

    @StateObject private var locationManager = LocationManager.shared
    @State private var cameraPosition: MapCameraPosition
    @State private var pinCoordinate: CLLocationCoordinate2D

    init(latitude: Binding<Double>, longitude: Binding<Double>, onDone: @escaping () -> Void) {
        _latitude = latitude
        _longitude = longitude
        self.onDone = onDone

        let lat = latitude.wrappedValue
        let lon = longitude.wrappedValue
        let coord = CLLocationCoordinate2D(
            latitude: lat == 0 ? 48.8566 : lat,
            longitude: lon == 0 ? 2.3522 : lon
        )
        _pinCoordinate = State(initialValue: coord)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )))
    }

    var body: some View {
        VStack(spacing: 0) {
            CustomNavBar(
                title: "Pick Location",
                showBack: true,
                showSettings: false,
                backAction: onDone
            )

            ZStack {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        Annotation("", coordinate: pinCoordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .onTapGesture { position in
                        if let coordinate = proxy.convert(position, from: .local) {
                            withAnimation {
                                pinCoordinate = coordinate
                                latitude = coordinate.latitude
                                longitude = coordinate.longitude
                            }
                        }
                    }
                }

                VStack {
                    Spacer()

                    HStack(spacing: 12) {
                        Button {
                            useCurrentLocation()
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.cardBackground)
                                .clipShape(Circle())
                                .shadow(color: AppTheme.cardShadow, radius: 4)
                        }

                        Button(action: onDone) {
                            Text("Confirm")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppTheme.accent)
                                .cornerRadius(AppTheme.cornerRadius)
                                .shadow(color: AppTheme.cardShadow, radius: 4)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.accent)
                Text(String(format: "%.4f, %.4f", pinCoordinate.latitude, pinCoordinate.longitude))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(AppTheme.secondaryText)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
        }
        .background(AppTheme.background)
        .onReceive(locationManager.$currentLocation) { location in
            guard let location = location else { return }
            if latitude == 0 && longitude == 0 {
                moveToCoordinate(location)
            }
        }
    }

    private func useCurrentLocation() {
        locationManager.requestLocation()
        if let location = locationManager.currentLocation {
            moveToCoordinate(location)
        }
    }

    private func moveToCoordinate(_ coord: CLLocationCoordinate2D) {
        withAnimation {
            pinCoordinate = coord
            latitude = coord.latitude
            longitude = coord.longitude
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
}
