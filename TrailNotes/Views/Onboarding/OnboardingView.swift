import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var storage: LocalStorage
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                TabView(selection: $currentPage) {
                    onboardingPage(
                        icon: "mountain.2.fill",
                        title: "Welcome to PathLog",
                        subtitle: "Save beautiful and useful places you discover on your adventures. Lakes, forests, viewpoints, and more.",
                        tag: 0
                    )

                    onboardingPage(
                        icon: "map.fill",
                        title: "Your Personal Map",
                        subtitle: "Organize places into trips, rate your favorites, and build a personal archive of your explorations.",
                        tag: 1
                    )
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Spacer()

                Button {
                    if currentPage == 0 {
                        withAnimation { currentPage = 1 }
                    } else {
                        storage.hasCompletedOnboarding = true
                    }
                } label: {
                    Text(currentPage == 0 ? "Next" : "Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.accent)
                        .cornerRadius(AppTheme.cornerRadius)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 40)
            }
        }
    }

    private func onboardingPage(icon: String, title: String, subtitle: String, tag: Int) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 70))
                .foregroundColor(AppTheme.accent)

            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .tag(tag)
    }
}
