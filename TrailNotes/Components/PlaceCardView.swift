import SwiftUI

struct PlaceCardView: View {
    let place: Place
    var onTap: () -> Void = {}
    var onFavorite: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if let firstPhotoID = place.photoIDs.first,
                       let image = PhotoManager.shared.loadImage(firstPhotoID) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(AppTheme.warmGray.opacity(0.3))
                            .frame(height: 160)
                            .overlay(
                                Image(systemName: place.category.icon)
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.warmGray)
                            )
                    }

                    Button(action: onFavorite) {
                        Image(systemName: place.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(place.isFavorite ? .red : .white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(10)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        CategoryBadge(category: place.category)
                        Spacer()
                        if place.rating > 0 {
                            RatingDisplay(rating: place.rating, compact: true)
                        }
                    }

                    Text(place.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !place.placeDescription.isEmpty {
                        Text(place.placeDescription)
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.secondaryText)
                            .lineLimit(2)
                    }

                    if !place.bestSeasons.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(place.bestSeasons) { season in
                                Image(systemName: season.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.accentLight)
                            }
                        }
                    }
                }
                .padding(12)
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.cardCornerRadius)
            .shadow(color: AppTheme.cardShadow, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
