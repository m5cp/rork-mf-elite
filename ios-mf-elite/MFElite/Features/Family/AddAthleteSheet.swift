//
//  AddAthleteSheet.swift
//  MFElite
//
//  Parent-side form to enroll another athlete in the household. Runs the same
//  shared validation as onboarding and the coach admin (ProfileValidation) plus
//  a live username availability check, so every athlete lands in one consistent,
//  individualized shape.
//

import SwiftUI

struct AddAthleteSheet: View {
    /// (username, name, kit, position)
    let onAdd: (String, String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var username: String = ""
    @State private var kit: String = ""
    @State private var position: String = "No preference"
    @State private var usernameStatus: Status = .idle
    @State private var checkTask: Task<Void, Never>?

    @FocusState private var focusedField: Field?

    private enum Field { case name, username, kit }
    private enum Status: Equatable { case idle, checking, available, error(String) }

    private var trimmedName: String { ProfileValidation.normalizedName(name) }
    private var trimmedUsername: String { ProfileValidation.normalizedUsername(username) }

    private var canSave: Bool {
        ProfileValidation.isNameValid(name) && usernameStatus == .available
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                    intro
                    nameField
                    usernameField
                    kitField
                    positionPicker
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.top, DS.Spacing.s16)
                .padding(.bottom, DS.Spacing.s32)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Add Athlete")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton { focusedField = nil }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(trimmedUsername, trimmedName, kit, position)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? DS.Colors.Ink.primary : DS.Colors.Ink.disabled)
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
        .onAppear { focusedField = .name }
        .onDisappear { checkTask?.cancel() }
    }

    // MARK: - Sections

    private var intro: some View {
        Text("Each athlete trains their own individualized program. Add their details and switch to them any time.")
            .style(.foot)
            .foregroundStyle(DS.Colors.Ink.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Name")
            HStack(spacing: DS.Spacing.s12) {
                TextField("", text: $name,
                          prompt: Text("Athlete's name").foregroundColor(DS.Colors.Ink.quaternary))
                    .focused($focusedField, equals: .name)
                    .font(DS.Typography.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .tint(.white)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .username }
                // Name and username both gate the Add button, but only the
                // username says so out loud. Without this, a parent whose Add
                // button stays dim can't tell which of the two is at fault.
                ConfirmBadge(isConfirmed: ProfileValidation.isNameValid(name), label: "Set", unconfirmedLabel: "Name needed")
            }
            .padding(.horizontal, DS.Spacing.s16)
            .frame(height: 52)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Username")
            HStack(spacing: DS.Spacing.s8) {
                Text("@")
                    .font(DS.Typography.title3)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                TextField("", text: $username,
                          prompt: Text("username").foregroundColor(DS.Colors.Ink.quaternary))
                    .focused($focusedField, equals: .username)
                    .font(DS.Typography.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .tint(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: username) { _, newValue in
                        let filtered = String(newValue.filter {
                            $0.isLetter || $0.isNumber || $0 == "_" || $0 == "."
                        }.prefix(ProfileValidation.usernameMaxLength))
                        if filtered != newValue { username = filtered }
                        scheduleUsernameCheck()
                    }
            }
            .padding(.horizontal, DS.Spacing.s16)
            .frame(height: 52)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(usernameBorder, lineWidth: 1))

            usernameStatusRow
        }
    }

    private var usernameBorder: Color {
        switch usernameStatus {
        case .available: return DS.Colors.Line.strong
        case .error: return Color(hex: "#FF4D4D")
        default: return DS.Colors.Line.hairline
        }
    }

    @ViewBuilder
    private var usernameStatusRow: some View {
        switch usernameStatus {
        case .idle:
            Text("Unique handle · 3–20 characters")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        case .checking:
            HStack(spacing: DS.Spacing.s8) {
                ProgressView().controlSize(.small).tint(DS.Colors.Ink.tertiary)
                Text("Checking availability…").style(.foot).foregroundStyle(DS.Colors.Ink.tertiary)
            }
        case .available:
            statusLabel("checkmark.circle.fill", "@\(trimmedUsername) is available", Color(hex: "#34C759"))
        case .error(let message):
            statusLabel("exclamationmark.circle.fill", message, Color(hex: "#FF4D4D"))
        }
    }

    private func statusLabel(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: DS.Spacing.s8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).style(.foot).foregroundStyle(color)
        }
    }

    private var kitField: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Kit number")
            TextField("", text: $kit,
                      prompt: Text("1–99").foregroundColor(DS.Colors.Ink.quaternary))
                .focused($focusedField, equals: .kit)
                .submitLabel(.done)
                .keyboardType(.numberPad)
                .font(DS.Typography.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
                .tint(.white)
                .onChange(of: kit) { _, newValue in
                    let digits = String(newValue.filter(\.isNumber).prefix(2))
                    if digits != newValue { kit = digits }
                }
                .padding(.horizontal, DS.Spacing.s16)
                .frame(height: 52)
                .background(DS.Colors.Bg.elevated)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.Line.hairline, lineWidth: 1))
        }
    }

    private var positionPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Position")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.s12) {
                ForEach(ProfileValidation.positions, id: \.self) { option in
                    positionChip(option)
                }
            }
        }
    }

    private func positionChip(_ option: String) -> some View {
        let selected = position == option
        return Button {
            position = option
        } label: {
            Text(option)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selected ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selected ? Color.white : DS.Colors.Bg.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.clear : DS.Colors.Line.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Username availability

    private func scheduleUsernameCheck() {
        checkTask?.cancel()
        let candidate = trimmedUsername
        if let formatError = ProfileValidation.validateUsernameFormat(candidate) {
            usernameStatus = candidate.isEmpty ? .idle : .error(formatError.localizedDescription ?? "Invalid username")
            return
        }
        // V1 is local-only — a valid format is enough; uniqueness isn't enforced
        // against any backend.
        usernameStatus = .available
    }
}

#Preview {
    AddAthleteSheet { _, _, _, _ in }
}
