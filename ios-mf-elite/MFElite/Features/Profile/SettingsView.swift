//
//  SettingsView.swift
//  MFElite
//
//  Full settings: account, subscription, notifications, coach access,
//  support links, and the danger zone (delete / sign out).
//

import SwiftUI
import SwiftData
import RevenueCat

struct SettingsRoute: Hashable {}

private enum AccountField: Identifiable {
    case name, kit, position
    var id: Int { hashValue }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var subscription
    @State private var auth = AuthService.shared
    @State private var profile = PlayerProfileStore.shared

    @AppStorage("MF_NOTIF_DAILY") private var dailyReminder = true
    @AppStorage("MF_NOTIF_STREAK") private var streakAlerts = true
    @AppStorage("MF_NOTIF_COACH") private var coachAnnouncements = true

    @State private var editingField: AccountField?
    @State private var showCoachLogin = false
    @State private var showDeleteConfirm = false
    @State private var showSignOutConfirm = false

    private let termsURL = URL(string: "https://mfelite.app/terms")!
    private let privacyURL = URL(string: "https://mfelite.app/privacy")!
    private let contactURL = URL(string: "mailto:support@mfelite.app")!
    private let manageSubscriptionURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                accountSection
                subscriptionSection
                notificationsSection
                coachSection
                supportSection
                dangerSection
                footerView
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCoachLogin) {
            CoachLoginView()
        }
        .sheet(item: $editingField) { field in
            AccountEditSheet(field: field, profile: profile)
                .preferredColorScheme(.dark)
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all your training data. This cannot be undone.")
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can sign back in any time to restore your progress.")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Settings")
            Text("Settings")
                .style(.title1)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s24)
    }

    // MARK: - Account

    private var accountSection: some View {
        section("Account", topPadding: DS.Spacing.s24) {
            if profile.onboardingSkipped {
                Text("Some details use defaults — tap any field to update.")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                    .padding(.bottom, DS.Spacing.s8)
            }
            valueRow(label: "Player name", value: profile.displayName) { editingField = .name }
            Hairline()
            valueRow(label: "Kit number", value: "#\(profile.kitNumber)") { editingField = .kit }
            Hairline()
            valueRow(label: "Position", value: profile.position.isEmpty ? "Not set" : profile.position) { editingField = .position }
            Hairline()
            valueRow(label: "Academy", value: "MF Elite", action: nil)
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        section("Subscription") {
            valueRow(label: "Current plan", value: subscription.isElite ? "Elite" : "Free (Trialist)", action: nil)
            Hairline()
            actionRow(label: "Manage subscription") { UIApplication.shared.open(manageSubscriptionURL) }
            Hairline()
            actionRow(label: "Restore purchases") { Task { await subscription.restorePurchases() } }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        section("Notifications") {
            toggleRow(label: "Daily reminder", isOn: $dailyReminder)
                .onChange(of: dailyReminder) { _, on in applyDailyReminder(on) }
            Hairline()
            toggleRow(label: "Streak alerts", isOn: $streakAlerts)
            Hairline()
            toggleRow(label: "Coach announcements", isOn: $coachAnnouncements)
        }
    }

    // MARK: - Coach

    private var coachSection: some View {
        section("Coach Access") {
            iconRow(icon: "lock.shield", label: "Coach workspace") { showCoachLogin = true }
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        section("Support") {
            actionRow(label: "Terms of Service") { UIApplication.shared.open(termsURL) }
            Hairline()
            actionRow(label: "Privacy Policy") { UIApplication.shared.open(privacyURL) }
            Hairline()
            actionRow(label: "Contact us") { UIApplication.shared.open(contactURL) }
            Hairline()
            actionRow(label: "Redeem a code") { Purchases.shared.presentCodeRedemptionSheet() }
        }
    }

    // MARK: - Danger zone

    private var dangerSection: some View {
        VStack(spacing: 0) {
            Button { showDeleteConfirm = true } label: {
                dangerLabel("Delete account")
            }
            .buttonStyle(PressableButtonStyle())
            Hairline()
            Button { showSignOutConfirm = true } label: {
                plainLabel("Sign out")
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: DS.Spacing.s4) {
            Text("MF ELITE v1.0.0")
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
            Text("BUILT BY M5CAIRIO")
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, DS.Spacing.s32)
    }

    // MARK: - Section scaffold

    private func section<Content: View>(
        _ title: String,
        topPadding: CGFloat = DS.Spacing.s32,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: title)
                .padding(.bottom, DS.Spacing.s4)
            content()
        }
        .padding(.horizontal, DS.Spacing.s20)
        .padding(.top, topPadding)
    }

    // MARK: - Rows

    private func valueRow(label: String, value: String, action: (() -> Void)?) -> some View {
        Group {
            if let action {
                Button(action: action) { rowContent(label: label, value: value, showChevron: true) }
                    .buttonStyle(PressableButtonStyle())
            } else {
                rowContent(label: label, value: value, showChevron: false)
            }
        }
    }

    private func rowContent(label: String, value: String, showChevron: Bool) -> some View {
        HStack(spacing: DS.Spacing.s12) {
            Text(label)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer(minLength: DS.Spacing.s12)
            Text(value)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .lineLimit(1)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
        }
        .padding(.vertical, DS.Spacing.s16 - 2)
        .contentShape(Rectangle())
    }

    private func actionRow(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s16 - 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func iconRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.s16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())
                Text(label)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            .padding(.vertical, DS.Spacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func toggleRow(label: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(label)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .tint(.white)
        .padding(.vertical, DS.Spacing.s12)
    }

    private func dangerLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .style(.title3)
                .foregroundStyle(Color.red.opacity(0.8))
            Spacer()
        }
        .padding(.vertical, DS.Spacing.s16 - 2)
        .contentShape(Rectangle())
    }

    private func plainLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer()
        }
        .padding(.vertical, DS.Spacing.s16 - 2)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func applyDailyReminder(_ on: Bool) {
        if on {
            NotificationService.shared.requestPermission { granted in
                if granted { NotificationService.shared.scheduleDailyReminder() }
            }
        } else {
            NotificationService.shared.cancelAll()
        }
    }

    private func signOut() {
        Task {
            await auth.signOut()
            profile.reset()
        }
    }

    private func deleteAccount() {
        Task {
            await auth.deleteAccount()
            clearLocalData()
            profile.reset()
        }
    }

    /// Clears the player's local progression so the next launch starts fresh.
    private func clearLocalData() {
        do {
            try modelContext.delete(model: DrillProgress.self)
            try modelContext.delete(model: PlayerState.self)
            try modelContext.save()
        } catch {
            print("[Settings] local data clear failed: \(error)")
        }
    }
}

// MARK: - Account Edit Sheet

private struct AccountEditSheet: View {
    let field: AccountField
    @Bindable var profile: PlayerProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var selectedPosition: String = ""
    @FocusState private var inputFocused: Bool

    private let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward", "Winger", "No preference"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                switch field {
                case .name:
                    field(title: "Player name") {
                        TextField("Your name", text: $text)
                            .textInputAutocapitalization(.words)
                            .focused($inputFocused)
                            .submitLabel(.done)
                            .styledInput()
                    }
                case .kit:
                    field(title: "Kit number") {
                        TextField("Number", text: $text)
                            .keyboardType(.numberPad)
                            .focused($inputFocused)
                            .styledInput()
                    }
                case .position:
                    field(title: "Position") {
                        VStack(spacing: DS.Spacing.s8) {
                            ForEach(positions, id: \.self) { pos in
                                positionRow(pos)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .background(DS.Colors.Bg.base)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton { inputFocused = false }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(DS.Colors.Ink.primary)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            Eyebrow(text: title)
            content()
        }
    }

    private func positionRow(_ pos: String) -> some View {
        let isSelected = selectedPosition == pos
        return Button {
            selectedPosition = pos
        } label: {
            HStack {
                Text(pos)
                    .style(.title3)
                    .foregroundStyle(isSelected ? DS.Colors.Ground.primary : DS.Colors.Ink.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DS.Colors.Ground.primary)
                }
            }
            .padding(.horizontal, DS.Spacing.s20)
            .frame(height: 56)
            .background(isSelected ? Color.white : DS.Colors.Bg.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(DS.Colors.Line.hairline, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var canSave: Bool {
        switch field {
        case .name: return !text.trimmingCharacters(in: .whitespaces).isEmpty
        case .kit: return !text.trimmingCharacters(in: .whitespaces).isEmpty
        case .position: return !selectedPosition.isEmpty
        }
    }

    private func load() {
        switch field {
        case .name: text = profile.displayName
        case .kit: text = profile.kitNumber
        case .position: selectedPosition = profile.position
        }
    }

    private func save() {
        switch field {
        case .name:
            profile.displayName = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .kit:
            let digits = text.filter(\.isNumber)
            profile.kitNumber = digits.isEmpty ? profile.kitNumber : digits
        case .position:
            profile.position = selectedPosition
        }
        dismiss()
    }
}

private extension View {
    func styledInput() -> some View {
        self
            .style(.title2)
            .foregroundStyle(DS.Colors.Ink.primary)
            .padding(.horizontal, DS.Spacing.s20)
            .frame(height: 56)
            .background(DS.Colors.Bg.elevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(SubscriptionService.shared)
    }
    .preferredColorScheme(.dark)
    .modelContainer(for: [
        Discipline.self, Category.self, MasteryLevel.self,
        Drill.self, DrillProgress.self, PlayerState.self
    ])
}
