//
//  CoachManageCoachesView.swift
//  MFElite
//
//  Head-coach-only team management: invite new coaches by email and
//  activate / deactivate existing ones. A coach gains access on first Sign in
//  with Apple using their invited email.
//

import SwiftUI

struct CoachManageCoachesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var coaches: [CoachRow] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAddForm = false

    private var activeCount: Int { coaches.filter { $0.isActive ?? true }.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                coachList
            }
            .background(DS.Colors.Bg.base)
            .navigationTitle("Manage Coaches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(DS.Colors.Ink.primary)
                }
            }
            .task { await load() }
            .sheet(isPresented: $showAddForm) {
                AddCoachSheet { email, name, role in
                    await addCoach(email: email, name: name, role: role)
                }
                .preferredColorScheme(.dark)
            }
        }
    }

    private var header: some View {
        HStack {
            Eyebrow(text: "Team")
            Spacer()
            Eyebrow(text: "\(activeCount) Active", color: DS.Colors.Ink.quaternary)
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s16)
        .padding(.bottom, DS.Spacing.s8)
    }

    @ViewBuilder
    private var coachList: some View {
        if isLoading {
            Spacer()
            ProgressView().tint(DS.Colors.Ink.primary)
            Spacer()
        } else {
            List {
                ForEach(coaches) { coach in
                    coachRow(coach)
                        .listRowBackground(DS.Colors.Bg.elevated)
                        .swipeActions(edge: .trailing) {
                            if coach.isActive ?? true {
                                Button(role: .destructive) {
                                    Task { await setActive(coach, active: false) }
                                } label: { Label("Deactivate", systemImage: "person.fill.xmark") }
                            } else {
                                Button {
                                    Task { await setActive(coach, active: true) }
                                } label: { Label("Reactivate", systemImage: "person.fill.checkmark") }
                                .tint(.green)
                            }
                        }
                }
                Button {
                    showAddForm = true
                } label: {
                    HStack(spacing: DS.Spacing.s8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add coach")
                            .style(.title3)
                    }
                    .foregroundStyle(DS.Colors.Ink.primary)
                }
                .listRowBackground(DS.Colors.Bg.elevated)

                if let errorMessage {
                    Text(errorMessage)
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DS.Colors.Bg.base)
        }
    }

    private func coachRow(_ coach: CoachRow) -> some View {
        let isActive = coach.isActive ?? true
        return HStack(spacing: DS.Spacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(coach.displayName ?? "Coach")
                    .style(.title3)
                    .foregroundStyle(isActive ? DS.Colors.Ink.primary : DS.Colors.Ink.quaternary)
                Text(coach.email ?? "")
                    .style(.micro)
                    .foregroundStyle(DS.Colors.Ink.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: DS.Spacing.s8)
            roleBadge(coach.role ?? "coach")
        }
        .padding(.vertical, DS.Spacing.s4)
        .opacity(isActive ? 1 : 0.5)
    }

    private func roleBadge(_ role: String) -> some View {
        Text(role == "head_coach" ? "HEAD COACH" : "COACH")
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(role == "head_coach" ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
            .padding(.vertical, 4)
            .padding(.horizontal, DS.Spacing.s8)
            .background(role == "head_coach" ? Color.white : DS.Colors.Bg.raised)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(DS.Colors.Line.hairline, lineWidth: role == "head_coach" ? 0 : 1)
            )
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            coaches = try await CoachContentService.shared.fetchCoaches()
        } catch {
            errorMessage = "Couldn't load coaches."
        }
    }

    private func addCoach(email: String, name: String, role: String) async {
        do {
            try await CoachContentService.shared.addCoach(email: email, displayName: name, role: role)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
        } catch {
            errorMessage = "Couldn't add coach. The email may already be in use."
        }
    }

    private func setActive(_ coach: CoachRow, active: Bool) async {
        do {
            try await CoachContentService.shared.setCoachActive(id: coach.id, active: active)
            await load()
        } catch {
            errorMessage = "Couldn't update coach."
        }
    }
}

// MARK: - Add Coach Sheet

private struct AddCoachSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var name = ""
    @State private var role = "coach"
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, name }

    let onInvite: (_ email: String, _ name: String, _ role: String) async -> Void

    private var canInvite: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                fieldBlock(title: "Email") {
                    TextField("coach@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .styledInput()
                }
                fieldBlock(title: "Display name") {
                    TextField("Coach name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)
                        .styledInput()
                }
                fieldBlock(title: "Role") {
                    Picker("Role", selection: $role) {
                        Text("Coach").tag("coach")
                        Text("Head Coach").tag("head_coach")
                    }
                    .pickerStyle(.segmented)
                }

                Text("The coach gains access by signing in with Apple using this email. Ask them to choose “Share My Email”.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.tertiary)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .background(DS.Colors.Bg.base)
            .navigationTitle("Add Coach")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton { focusedField = nil }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Invite") { invite() }
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .fontWeight(.semibold)
                        .disabled(!canInvite || isSaving)
                }
            }
        }
    }

    private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: title)
            content()
        }
    }

    private func invite() {
        guard canInvite, !isSaving else { return }
        isSaving = true
        Task {
            await onInvite(email, name, role)
            dismiss()
        }
    }
}

private extension View {
    func styledInput() -> some View {
        self
            .style(.title3)
            .foregroundStyle(DS.Colors.Ink.primary)
            .padding(.horizontal, DS.Spacing.s20)
            .frame(height: 56)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
