//
//  EditProfileSheet.swift
//  MFElite
//
//  Lets the player edit their avatar, name, and kit number in one place.
//  Changes save to the local PlayerProfileStore.
//

import SwiftUI

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var profile = PlayerProfileStore.shared

    @State private var name: String = ""
    @State private var kit: String = ""
    @State private var gender: String = ""
    @State private var birthYear: Int = 0
    @State private var showAvatarPicker = false

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Plausible player birth years, newest first.

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.s24) {
                    avatarRow

                    VStack(spacing: DS.Spacing.s16) {
                        field(label: "Name") {
                            TextField("Your name", text: $name)
                                .textInputAutocapitalization(.words)
                                .submitLabel(.done)
                                .onChange(of: name) { _, newValue in
                                    if newValue.count > 28 { name = String(newValue.prefix(28)) }
                                }
                        }
                        field(label: "Kit number") {
                            TextField("e.g. 10", text: $kit)
                                .keyboardType(.numberPad)
                                .onChange(of: kit) { _, newValue in
                                    let digits = newValue.filter(\.isNumber)
                                    kit = String(digits.prefix(2))
                                }
                        }
                        field(label: "Grading category") {
                            Picker("Grading category", selection: $gender) {
                                Text("Male").tag("male")
                                Text("Female").tag("female")
                                Text("Prefer not to say").tag("")
                            }
                            .pickerStyle(.menu)
                            .tint(DS.Colors.Ink.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        field(label: "Birth year") {
                            BirthYearField(year: $birthYear)
                        }
                    }
                }
                .padding(DS.Spacing.s20)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAvatarPicker) {
                AvatarPickerSheet()
            }
        }
        .onAppear {
            name = profile.displayName == "Player" ? "" : profile.displayName
            kit = profile.kitNumber
            gender = profile.gender
            birthYear = profile.birthYear
        }
    }

    private var avatarRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showAvatarPicker = true
        } label: {
            VStack(spacing: DS.Spacing.s12) {
                AvatarView(
                    selection: profile.avatar,
                    photo: profile.avatarPhoto,
                    initials: profile.initials,
                    kit: profile.kitNumber,
                    size: 96,
                    shape: .circle
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 28)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DS.Colors.Bg.base, lineWidth: 2))
                }
                Text("Change avatar")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Change avatar")
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: label)
            content()
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.Ink.primary)
                .tint(.white)
                .padding(DS.Spacing.s16)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.displayName = trimmed.isEmpty ? "Player" : trimmed
        profile.kitNumber = kit
        profile.gender = gender
        profile.birthYear = birthYear
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // Push the updated identity (incl. gender) up when signed in.
        Task { await SupabaseAuth.shared.syncPlayerProfile() }
        if SupabaseAuth.shared.isSignedIn { SupabaseAuth.shared.pushFullProfile() }
        dismiss()
    }
}

#Preview {
    EditProfileSheet()
        .preferredColorScheme(.dark)
}
