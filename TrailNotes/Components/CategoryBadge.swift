import SwiftUI

struct CategoryBadge: View {
    let category: PlaceCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(category.rawValue)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(AppTheme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppTheme.accent.opacity(0.12))
        .cornerRadius(AppTheme.smallCornerRadius)
    }
}
