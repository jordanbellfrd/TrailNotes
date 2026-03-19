import SwiftUI

struct CustomNavBar: View {
    let title: String
    var showBack: Bool = false
    var showSettings: Bool = true
    var backAction: (() -> Void)? = nil
    var settingsAction: (() -> Void)? = nil
    var trailingItems: [NavBarItem] = []

    var body: some View {
        HStack(spacing: 12) {
            if showBack {
                Button(action: { backAction?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                }
            }

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            ForEach(trailingItems) { item in
                Button(action: item.action) {
                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
            }

            if showSettings {
                Button(action: { settingsAction?() }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .padding(.horizontal, AppTheme.horizontalPadding)
        .padding(.vertical, 12)
        .background(AppTheme.background)
    }
}

struct NavBarItem: Identifiable {
    let id = UUID()
    let icon: String
    let action: () -> Void
}
