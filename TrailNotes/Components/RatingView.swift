import SwiftUI

struct RatingDisplay: View {
    let rating: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: compact ? 10 : 14))
                    .foregroundColor(star <= rating ? .orange : AppTheme.secondaryText.opacity(0.4))
            }
        }
    }
}

struct RatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        rating = star == rating ? 0 : star
                    }
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundColor(star <= rating ? .orange : AppTheme.secondaryText.opacity(0.3))
                }
            }
        }
    }
}
