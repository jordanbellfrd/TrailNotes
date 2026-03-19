import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var storage: LocalStorage

    var body: some View {
        Group {
            if storage.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.light)
    }
}
