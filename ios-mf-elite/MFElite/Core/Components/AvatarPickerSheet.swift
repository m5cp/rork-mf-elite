//
//  AvatarPickerSheet.swift
//  MFElite
//
//  Lets the player choose an avatar: upload a photo from the library or pick
//  one of the built-in MF designs. Writes the choice straight to the store.
//

import SwiftUI
import PhotosUI

struct AvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var profile = PlayerProfileStore.shared

    @State private var photoItem: PhotosPickerItem?
    @State private var isLoading = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.s12), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    currentPreview

                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        HStack(spacing: DS.Spacing.s12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Upload a photo")
                                .style(.title3)
                            Spacer()
                            if isLoading {
                                ProgressView().tint(DS.Colors.Ink.primary)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(DS.Colors.Ink.quaternary)
                            }
                        }
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .padding(DS.Spacing.s16)
                        .background(DS.Colors.Bg.raised)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .disabled(isLoading)

                    VStack(alignment: .leading, spacing: DS.Spacing.s12) {
                        Eyebrow(text: "MF Avatars")
                        LazyVGrid(columns: columns, spacing: DS.Spacing.s12) {
                            ForEach(PlayerProfileStore.builtinAvatarIDs, id: \.self) { id in
                                builtinTile(id)
                            }
                        }
                    }

                    if profile.avatar != .none {
                        Button(role: .destructive) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            profile.clearAvatar()
                            dismiss()
                        } label: {
                            Text("Remove avatar")
                                .style(.title3)
                                .foregroundStyle(Color(hex: "#FF453A"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(DS.Colors.Bg.raised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                                .padding(.vertical, DS.Spacing.s16)
                        }
                    }
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Choose Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            isLoading = true
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    profile.setPhotoAvatar(image)
                    if SupabaseAuth.shared.isSignedIn { SupabaseAuth.shared.pushFullProfile() }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    isLoading = false
                    dismiss()
                } else {
                    isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private var currentPreview: some View {
        HStack {
            Spacer()
            AvatarView(
                selection: profile.avatar,
                photo: profile.avatarPhoto,
                initials: profile.initials,
                kit: profile.kitNumber,
                size: 96,
                shape: .circle
            )
            Spacer()
        }
    }

    private func builtinTile(_ id: String) -> some View {
        let isSelected = profile.avatar == .builtin(id)
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            profile.setBuiltinAvatar(id)
            if SupabaseAuth.shared.isSignedIn { SupabaseAuth.shared.pushFullProfile() }
        } label: {
            AvatarView(
                selection: .builtin(id),
                photo: nil,
                initials: profile.initials,
                kit: nil,
                size: 96,
                shape: .roundedRect(DS.Radius.md)
            )
            // Selection ring attaches to the 96pt tile BEFORE the flexible
            // frame, so it always hugs the avatar exactly.
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(DS.Colors.Gold.base, lineWidth: isSelected ? 3 : 0)
            )
            .overlay(alignment: .bottomTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DS.Colors.Gold.inkOnGold, DS.Colors.Gold.base)
                        .background(Circle().fill(DS.Colors.Bg.base))
                        .offset(x: 6, y: 6)
                }
            }
            .scaleEffect(isSelected ? 1.04 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    AvatarPickerSheet()
        .preferredColorScheme(.dark)
}
