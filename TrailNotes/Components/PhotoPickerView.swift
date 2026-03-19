import SwiftUI
import PhotosUI

struct PhotoPickerButton: View {
    var maxSelection: Int = 5
    var onPicked: ([UIImage]) -> Void

    @State private var selectedItems: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: maxSelection,
            matching: .images
        ) {
            HStack(spacing: 6) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 15, weight: .medium))
                Text("Add Photos")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(AppTheme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppTheme.accent.opacity(0.12))
            .cornerRadius(AppTheme.smallCornerRadius)
        }
        .onChange(of: selectedItems) { _, items in
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                await MainActor.run {
                    onPicked(images)
                    selectedItems = []
                }
            }
        }
    }
}

struct PhotoGridView: View {
    let photoIDs: [UUID]
    var onDelete: ((UUID) -> Void)? = nil
    var editable: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(photoIDs, id: \.self) { photoID in
                if let image = PhotoManager.shared.loadImage(photoID) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minHeight: 100)
                            .clipped()
                            .cornerRadius(AppTheme.smallCornerRadius)

                        if editable, let onDelete = onDelete {
                            Button {
                                onDelete(photoID)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(4)
                        }
                    }
                }
            }
        }
    }
}
