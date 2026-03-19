import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(AppTheme.warmGray)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            if let buttonTitle = buttonTitle, let action = buttonAction {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.accent)
                        .cornerRadius(AppTheme.cornerRadius)
                }
                .padding(.top, 4)
            }
        }
        .padding(40)
    }
}
