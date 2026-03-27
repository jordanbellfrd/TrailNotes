import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var storage: LocalStorage

    @State var isLoading: Bool = true

    var body: some View {
        ZStack {
            if isLoading {
                Loading(isLoading: $isLoading)
                    .environmentObject(storage)
            } else {
                if storage.hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

struct Loading: View {

    @Binding var isLoading: Bool

    @State var url: String? = nil
    @State var webViewConfig: WebViewConfiguration = WebViewConfiguration()
    @State var dynamicBackgroundColor: Color? = nil

    var body: some View {
        ZStack {
            if url == nil {
                // Custom loading screen matching TrailNotes style
                AppTheme.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AppTheme.accent)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("TrailNotes")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    ProgressView()
                        .tint(AppTheme.accent)
                        .scaleEffect(1.2)
                }
            } else {
                // Dynamic background based on config
                if webViewConfig.ui.webViewBackgroundColor == "auto" {
                    if let dynamicColor = dynamicBackgroundColor {
                        dynamicColor.ignoresSafeArea()
                    } else if #available(iOS 15.0, *) {
                        Color.clear.ignoresSafeArea()
                    } else {
                        Color(.systemBackground).ignoresSafeArea()
                    }
                } else if let bgColor = webViewConfig.ui.webViewBackgroundColor {
                    Color(hex: bgColor).ignoresSafeArea()
                }

                SwiftUIWebView(url: URL(string: url!)!, configuration: webViewConfig)
                    .ignoresSafeArea(.all)
                    .id(webViewConfig.ui.webViewBackgroundColor ?? "auto")
            }
        }.onAppear {
            webViewConfig = DataCollectorAttribution.shared.loadWebViewConfiguration()

            NotificationCenter.default.addObserver(forName: .serverResponseReceived, object: nil, queue: .main) { notification in
                if let response = notification.object as? String {
                    logPrint(response)
                    url = response
                } else {
                    DispatchQueue.main.async {
                        isLoading = false
                    }
                }
            }

            NotificationCenter.default.addObserver(forName: .webViewConfigurationUpdated, object: nil, queue: .main) { notification in
                if let updatedConfig = notification.object as? WebViewConfiguration {
                    logPrint("🔄 WebView config updated in ContentView")
                    logPrint("🎨 New background color: \(updatedConfig.ui.webViewBackgroundColor ?? "auto")")
                    webViewConfig = updatedConfig
                }
            }

            NotificationCenter.default.addObserver(forName: .pageBackgroundColorChanged, object: nil, queue: .main) { notification in
                if let color = notification.object as? UIColor {
                    logPrint("🎨 ContentView received page background color: \(color)")
                    dynamicBackgroundColor = Color(uiColor: color)
                }
            }
        }
    }
}
