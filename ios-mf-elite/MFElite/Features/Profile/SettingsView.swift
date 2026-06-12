//
//  SettingsView.swift
//  MFElite
//
//  Full settings: account, subscription, notifications, and support links.
//  V1 is local-only — no account, so no sign out or delete account.
//

import SwiftUI
import SwiftData
import RevenueCat
import MessageUI
import AppIntents

struct SettingsRoute: Hashable {}

private enum AccountField: Identifiable {
    case name, kit, position, birthYear
    var id: Int { hashValue }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var subscription
    @State private var profile = PlayerProfileStore.shared

    @AppStorage("MF_NOTIF_DAILY") private var dailyReminder = true
    @AppStorage("MF_NOTIF_STREAK") private var streakAlerts = true
    @AppStorage("MF_AUTO_ADVANCE") private var autoAdvance = true

    @State private var health = HealthKitService.shared
    @State private var gate = ParentGate.shared
    @State private var auth = SupabaseAuth.shared
    @State private var sync = SyncEngine.shared

    @State private var showSignInSheet = false
    @State private var showSignOutConfirm = false

    @State private var editingField: AccountField?
    @State private var gateMode: ParentGateMode?
    @State private var showDisableGateConfirm = false
    @State private var mailRequest: MailRequest?
    @State private var showMailUnavailable = false
    @State private var pendingSupportSubject = ""

    private let supportEmail = "mf.elitetraining@gmail.com"
    private let manageSubscriptionURL = URL(string: "https://apps.apple.com/account/subscriptions")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                accountSection
                syncSection
                subscriptionSection
                familySafetySection
                trainingSection
                if health.isAvailable { healthSection }
                notificationsSection
                siriSection
                supportSection
                footerView
            }
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingField) { field in
            AccountEditSheet(field: field, profile: profile)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $gateMode) { mode in
            ParentGateView(mode: mode)
                .preferredColorScheme(.dark)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showSignInSheet) {
            AccountSyncSignInSheet { showSignInSheet = false }
                .preferredColorScheme(.dark)
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Sign out of this account?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { auth.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your training data stays on this device. You can sign back in anytime.")
        }
        .confirmationDialog(
            "Turn off the parent passcode?",
            isPresented: $showDisableGateConfirm,
            titleVisibility: .visible
        ) {
            Button("Turn off passcode", role: .destructive) { gate.disable() }
            Button("Keep it on", role: .cancel) {}
        } message: {
            Text("Purchases and family settings will no longer require a passcode.")
        }
        .sheet(item: $mailRequest) { request in
            MailComposeView(request: request).ignoresSafeArea()
        }
        .alert("Email not set up", isPresented: $showMailUnavailable) {
            Button("Copy address") { UIPasteboard.general.string = supportEmail }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Reach us at \(supportEmail)")
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
            valueRow(label: "Age", value: ageValue) { editingField = .birthYear }
            Hairline()
            valueRow(label: "Academy", value: "MF Elite", action: nil)
        }
    }

    // MARK: - Account Sync

    private var syncSection: some View {
        section("Sync") {
            HStack(spacing: DS.Spacing.s12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.isSignedIn ? "Signed in" : "Local only")
                        .style(.title3)
                        .foregroundStyle(DS.Colors.Ink.primary)
                    Text(syncStatusDetail)
                        .style(.callout)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: DS.Spacing.s12)
                if auth.isSignedIn {
                    Button("Sign out") { showSignOutConfirm = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .buttonStyle(PressableButtonStyle())
                } else {
                    Button { showSignInSheet = true } label: {
                        Text("SIGN IN")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(DS.Colors.Ground.primary)
                            .padding(.vertical, 5)
                            .padding(.horizontal, DS.Spacing.s12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.vertical, DS.Spacing.s16 - 2)

            if auth.isSignedIn {
                Hairline()
                HStack(spacing: DS.Spacing.s12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lastSyncedText)
                            .style(.callout)
                            .foregroundStyle(DS.Colors.Ink.secondary)
                        if sync.pendingCount > 0 {
                            Text("\(sync.pendingCount) change\(sync.pendingCount == 1 ? "" : "s") waiting to upload")
                                .style(.foot)
                                .foregroundStyle(DS.Colors.Ink.tertiary)
                        }
                    }
                    Spacer(minLength: DS.Spacing.s12)
                    Button("Sync now") { sync.syncNow() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.secondary)
                        .buttonStyle(PressableButtonStyle())
                }
                .padding(.vertical, DS.Spacing.s16 - 2)
            }

            Text("Sign in with Apple to back up your progress and restore it on another device. The app works fully offline either way.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, DS.Spacing.s8)
        }
    }

    private var syncStatusDetail: String {
        if auth.isSignedIn { return auth.email ?? "Apple account" }
        return "Not backed up"
    }

    private var lastSyncedText: String {
        guard let date = sync.lastSyncedAt else { return "Not synced yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last synced \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        section("Subscription") {
            currentPlanRow
            Hairline()
            actionRow(label: "Manage subscription") {
                protected("Unlock to manage") { UIApplication.shared.open(manageSubscriptionURL) }
            }
            Hairline()
            actionRow(label: "Restore purchases") {
                protected("Unlock to restore") { Task { await subscription.restorePurchases() } }
            }
        }
    }

    private var ageValue: String {
        if let age = profile.age { return "\(age) yrs" }
        return "Not set"
    }

    // MARK: - Family Safety

    private var familySafetySection: some View {
        section("Family Safety") {
            toggleRow(label: "Require parent passcode", isOn: Binding(
                get: { gate.isEnabled },
                set: { applyGateToggle($0) }
            ))
            Text("When on, buying or managing a subscription and restoring purchases ask for a 4-digit passcode only a parent knows. This is in addition to Apple’s Ask to Buy and Screen Time.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, DS.Spacing.s8)
            if gate.hasPIN {
                Hairline()
                actionRow(label: "Change passcode") { gateMode = .set }
            }
        }
    }

    private func applyGateToggle(_ on: Bool) {
        if on {
            gateMode = .set
        } else if gate.hasPIN {
            showDisableGateConfirm = true
        } else {
            gate.disable()
        }
    }

    /// Run a parent-only action, gating it behind the passcode when enabled.
    private func protected(_ title: String, _ action: @escaping () -> Void) {
        if gate.isEnabled && gate.hasPIN {
            gateMode = .verify(title: title, onSuccess: action)
        } else {
            action()
        }
    }

    private var currentPlanRow: some View {
        HStack(spacing: DS.Spacing.s12) {
            Text("Current plan")
                .style(.title3)
                .foregroundStyle(DS.Colors.Ink.primary)
            Spacer(minLength: DS.Spacing.s12)
            Text(planLabel)
                .style(.callout)
                .foregroundStyle(DS.Colors.Ink.tertiary)
                .lineLimit(1)
            if !subscription.hasFullAccess {
                Button {
                    protected("Unlock to upgrade") { subscription.presentPaywall() }
                } label: {
                    Text("UPGRADE")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(DS.Colors.Ground.primary)
                        .padding(.vertical, 5)
                        .padding(.horizontal, DS.Spacing.s12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Upgrade to Elite")
            }
        }
        .padding(.vertical, DS.Spacing.s16 - 2)
        .contentShape(Rectangle())
    }

    private var planLabel: String {
        subscription.isElite ? "Elite" : "Free (Trialist)"
    }

    // MARK: - Training

    private var trainingSection: some View {
        section("Training") {
            toggleRow(label: "Auto-advance drills", isOn: $autoAdvance)
            Text("In a routine or workout, the next drill loads automatically a few seconds after you log one. You always tap to start its timer.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, DS.Spacing.s8)
        }
    }

    // MARK: - Apple Health

    private var healthSection: some View {
        section("Apple Health") {
            toggleRow(label: "Log to Apple Health", isOn: Binding(
                get: { health.isSyncEnabled },
                set: { applyHealthSync($0) }
            ))
            Text("Save each completed session to Apple Health as a soccer workout, so your training counts toward your activity rings.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, DS.Spacing.s8)
        }
    }

    private func applyHealthSync(_ on: Bool) {
        if on {
            health.enableSync { _ in }
        } else {
            health.disableSync()
        }
    }

    // MARK: - Siri

    private var siriSection: some View {
        section("Siri Shortcuts") {
            SiriTipView(intent: StartTrainingIntent())
                .siriTipViewStyle(.dark)
                .padding(.vertical, DS.Spacing.s8)
            Text("Ask Siri to start your training hands-free, or add these actions to your own Shortcuts.")
                .style(.foot)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, DS.Spacing.s8)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        section("Notifications") {
            toggleRow(label: "Daily reminder", isOn: $dailyReminder)
                .onChange(of: dailyReminder) { _, on in applyDailyReminder(on) }
            Hairline()
            toggleRow(label: "Streak alerts", isOn: $streakAlerts)
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        section("Legal & Support") {
            NavigationLink { TermsOfUseView() } label: { actionRowLabel("Terms of Use") }
                .buttonStyle(PressableButtonStyle())
            Hairline()
            NavigationLink { PrivacyPolicyView() } label: { actionRowLabel("Privacy Policy") }
                .buttonStyle(PressableButtonStyle())
            Hairline()
            NavigationLink { DisclaimerView() } label: { actionRowLabel("Disclaimer") }
                .buttonStyle(PressableButtonStyle())
            Hairline()
            NavigationLink { EULAView() } label: { actionRowLabel("License Agreement") }
                .buttonStyle(PressableButtonStyle())
            Hairline()
            NavigationLink { AccessibilityView() } label: { actionRowLabel("Accessibility") }
                .buttonStyle(PressableButtonStyle())
            Hairline()
            iconRow(icon: "envelope", label: "Contact Support") {
                composeSupport(subject: "MF Elite Support — \(profile.displayName)")
            }
            Hairline()
            iconRow(icon: "exclamationmark.bubble", label: "Report a Problem") {
                composeSupport(subject: "MF Elite — Report a Problem")
            }
        }
    }

    private func composeSupport(subject: String) {
        if MFMailComposeViewController.canSendMail() {
            mailRequest = MailRequest(
                recipient: supportEmail,
                subject: subject,
                body: MailRequest.supportBody()
            )
        } else {
            pendingSupportSubject = subject
            showMailUnavailable = true
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: DS.Spacing.s12) {
            Text("Your training data is stored on this device. Deleting the app will erase your progress.")
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.quaternary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.s12)

            VStack(spacing: DS.Spacing.s4) {
                Text("MF ELITE v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
                Text("BUILT BY M5CAIRIO")
                    .style(.microSm)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
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
            actionRowLabel(label)
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func actionRowLabel(_ label: String) -> some View {
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

}

// MARK: - Account Edit Sheet

private struct AccountEditSheet: View {
    let field: AccountField
    @Bindable var profile: PlayerProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var selectedPosition: String = ""
    @State private var selectedBirthYear: Int = 0
    @FocusState private var inputFocused: Bool

    private var birthYearRange: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 60)...(current - 4)).reversed()
    }

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
                case .birthYear:
                    field(title: "Year of birth") {
                        Text("Used to tailor age-appropriate guidance. Stored only on this device.")
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                            .fixedSize(horizontal: false, vertical: true)
                        Picker("Year of birth", selection: $selectedBirthYear) {
                            Text("Not set").tag(0)
                            ForEach(birthYearRange, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .tint(DS.Colors.Ink.primary)
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
        case .birthYear: return true
        }
    }

    private func load() {
        switch field {
        case .name: text = profile.displayName
        case .kit: text = profile.kitNumber
        case .position: selectedPosition = profile.position
        case .birthYear: selectedBirthYear = profile.birthYear
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
        case .birthYear:
            profile.birthYear = selectedBirthYear
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
