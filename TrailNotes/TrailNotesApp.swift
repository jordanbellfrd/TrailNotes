import SwiftUI

@main
struct TrailNotesApp: App {
    @StateObject private var storage = LocalStorage()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storage)
        }
    }
}
