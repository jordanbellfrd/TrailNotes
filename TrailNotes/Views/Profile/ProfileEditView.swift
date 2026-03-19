import SwiftUI
import PhotosUI
import Combine

struct ProfileEditView: View {
    @EnvironmentObject var storage: LocalStorage
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var avatarPhotoID: UUID? = nil
    @State private var selectedAvatarItem: [PhotosPickerItem] = []

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    avatarSection
                    nameSection
                    saveButton
                }
                .padding(.top, 56)
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 40)
            }

            CustomNavBar(
                title: "Edit Profile",
                showBack: true,
                showSettings: false,
                backAction: { dismiss() }
            )
        }
        .onAppear {
            name = storage.profile.name
            avatarPhotoID = storage.profile.avatarPhotoID
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            if let avatarID = avatarPhotoID,
               let image = PhotoManager.shared.loadImage(avatarID) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(AppTheme.accent)
                    )
            }

            PhotosPicker(selection: $selectedAvatarItem, maxSelectionCount: 1, matching: .images) {
                Text("Change Photo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }
            .onChange(of: selectedAvatarItem) { _, items in
                guard let item = items.first else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            if let oldID = avatarPhotoID {
                                PhotoManager.shared.deletePhoto(oldID)
                            }
                            avatarPhotoID = PhotoManager.shared.savePhoto(image)
                            selectedAvatarItem = []
                        }
                    }
                }
            }

            if avatarPhotoID != nil {
                Button("Remove Photo") {
                    if let id = avatarPhotoID {
                        PhotoManager.shared.deletePhoto(id)
                    }
                    avatarPhotoID = nil
                }
                .font(.system(size: 13))
                .foregroundColor(AppTheme.destructive)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NAME")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.secondaryText)

            TextField("Your name", text: $name)
                .font(.system(size: 16))
                .padding(12)
                .background(AppTheme.cardBackground)
                .cornerRadius(AppTheme.cornerRadius)
                .shadow(color: AppTheme.cardShadow, radius: 2)
        }
    }

    private var saveButton: some View {
        Button {
            var profile = UserProfile()
            profile.name = name
            profile.avatarPhotoID = avatarPhotoID
            storage.updateProfile(profile)
            dismiss()
        } label: {
            Text("Save Profile")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.accent)
                .cornerRadius(AppTheme.cornerRadius)
        }
    }
}
