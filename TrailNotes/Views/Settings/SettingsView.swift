import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject var storage: LocalStorage
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false
    @State private var showExportShare = false
    @State private var exportURL: URL? = nil

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    mapSection
                    unitsSection
                    dataSection
                    aboutSection
                }
                .padding(.top, 56)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 40)
            }

            CustomNavBar(
                title: "Settings",
                showBack: true,
                showSettings: false,
                backAction: { dismiss() }
            )
        }
        .alert("Reset All Data", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                storage.resetAllData()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all places, trips, and photos. This cannot be undone.")
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private var mapSection: some View {
        settingsCard(title: "Map") {
            VStack(spacing: 12) {
                HStack {
                    Label("Map Style", systemImage: "map")
                        .font(.system(size: 15))
                    Spacer()
                    Picker("", selection: $storage.settings.mapDisplayStyle) {
                        ForEach(MapDisplayStyle.allCases, id: \.self) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.accent)
                }
            }
        }
    }

    private var unitsSection: some View {
        settingsCard(title: "Units") {
            HStack {
                Label("Distance", systemImage: "ruler")
                    .font(.system(size: 15))
                Spacer()
                Picker("", selection: $storage.settings.distanceUnit) {
                    ForEach(DistanceUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.accent)
            }
        }
    }

    private var dataSection: some View {
        settingsCard(title: "Data") {
            VStack(spacing: 14) {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    .foregroundColor(.primary)
                }

                Divider()

                Button {
                    showResetConfirm = true
                } label: {
                    HStack {
                        Label("Reset All Data", systemImage: "trash")
                            .font(.system(size: 15))
                        Spacer()
                    }
                    .foregroundColor(AppTheme.destructive)
                }
            }
        }
    }

    private var aboutSection: some View {
        settingsCard(title: "About") {
            VStack(spacing: 10) {
                HStack {
                    Text("Version")
                        .font(.system(size: 15))
                    Spacer()
                    Text("1.0.0")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.secondaryText)
                }
                HStack {
                    Text("Places Saved")
                        .font(.system(size: 15))
                    Spacer()
                    Text("\(storage.totalPlaces)")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.secondaryText)
                }
                HStack {
                    Text("Trips Created")
                        .font(.system(size: 15))
                    Spacer()
                    Text("\(storage.totalTrips)")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
    }

    private func settingsCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)

            VStack(spacing: 0) {
                content()
            }
            .padding(14)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cornerRadius)
            .shadow(color: AppTheme.cardShadow, radius: 2, x: 0, y: 1)
        }
    }

    private func exportData() {
        guard let data = storage.exportJSON() else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PathLog_Export.json")
        try? data.write(to: tempURL)
        exportURL = tempURL
        showExportShare = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
