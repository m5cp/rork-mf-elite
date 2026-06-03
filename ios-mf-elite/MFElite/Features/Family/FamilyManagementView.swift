//
//  FamilyManagementView.swift
//  MFElite
//
//  Household roster management. One account can manage several athletes, but the
//  program is INDIVIDUALIZED: only the athlete set as active sees their tailored
//  sessions, drills, and progress on this device. Switching the active athlete
//  switches the whole app over to that athlete's program.
//

import SwiftUI

struct FamilyRoute: Hashable {}

struct FamilyManagementView: View {
    @State private var family = FamilyStore.shared
    @State private var showAddAthlete = false
    @State private var athleteToRemove: Athlete?
    @State private var switching: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s24) {
                header
                individualizedNote
                activeBanner
                roster
                addButton
            }
            .padding(.horizontal, DS.Spacing.s20)
            .padding(.top, DS.Spacing.s24)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.Bg.base)
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddAthlete) {
            AddAthleteSheet { username, name, kit, position in
                addAthlete(username: username, name: name, kit: kit, position: position)
            }
        }
        .confirmationDialog(
            "Remove this athlete from your household?",
            isPresented: removeBinding,
            titleVisibility: .visible
        ) {
            Button("Remove athlete", role: .destructive) {
                if let athlete = athleteToRemove { remove(athlete) }
            }
            Button("Keep", role: .cancel) { athleteToRemove = nil }
        } message: {
            Text("Their individualized program and progress will be removed from this device.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            Eyebrow(text: "Household")
            Text("Family")
                .style(.hero)
                .foregroundStyle(DS.Colors.Ink.primary)
            Text("Manage every athlete in your household from one account. Each athlete keeps their own card, kit number, and progress.")
                .style(.body)
                .foregroundStyle(DS.Colors.Ink.tertiary)
        }
    }

    // MARK: - Individualized note

    private var individualizedNote: some View {
        Card {
            HStack(alignment: .top, spacing: DS.Spacing.s12) {
                Image(systemName: "person.fill.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.Colors.Ink.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.Colors.Bg.raised)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                    Eyebrow(text: "Individualized Program", color: DS.Colors.Ink.primary)
                    Text("Every athlete trains a tailored program built just for them. Only the athlete set as active sees their sessions, drills, and progress on this device — switch active athletes any time.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Active banner

    @ViewBuilder
    private var activeBanner: some View {
        if let active = family.activeAthlete {
            Card(raised: true) {
                HStack(spacing: DS.Spacing.s16) {
                    Monogram(size: 56, initials: active.initials, kit: active.kitNumber)
                    VStack(alignment: .leading, spacing: DS.Spacing.s4) {
                        Eyebrow(text: "Now Training")
                        Text(active.displayName)
                            .style(.title2)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text(active.position.isEmpty ? "No preference" : active.position)
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.tertiary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Roster

    private var roster: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            HStack(alignment: .firstTextBaseline) {
                SectionHead(title: "Athletes")
                Spacer(minLength: 0)
                Text("\(family.athletes.count)")
                    .style(.foot)
                    .foregroundStyle(DS.Colors.Ink.quaternary)
            }
            ForEach(family.athletes) { athlete in
                athleteCard(athlete)
            }
        }
    }

    private func athleteCard(_ athlete: Athlete) -> some View {
        let isActive = family.isActive(athlete)
        return Card {
            VStack(spacing: DS.Spacing.s16) {
                HStack(spacing: DS.Spacing.s16) {
                    Monogram(size: 52, initials: athlete.initials, kit: athlete.kitNumber)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(athlete.displayName)
                            .style(.title3)
                            .foregroundStyle(DS.Colors.Ink.primary)
                        Text(athleteSubtitle(athlete))
                            .style(.foot)
                            .foregroundStyle(DS.Colors.Ink.quaternary)
                    }

                    Spacer(minLength: 0)

                    if isActive {
                        activePill
                    }
                }

                if isActive {
                    Text("This athlete's individualized program is showing across the app.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: DS.Spacing.s12) {
                        Button {
                            switchTo(athlete)
                        } label: {
                            Text(switching == athlete.id ? "Switching…" : "View their program")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DS.Colors.Ground.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
                        }
                        .buttonStyle(PressableButtonStyle())

                        if athlete.managed {
                            IconButton(systemName: "trash") {
                                athleteToRemove = athlete
                            }
                        }
                    }
                }
            }
        }
    }

    private var activePill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
            Text("ACTIVE")
                .style(.microSm)
                .foregroundStyle(DS.Colors.Ink.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DS.Colors.Bg.raised)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(DS.Colors.Line.subtle, lineWidth: 1))
    }

    private func athleteSubtitle(_ athlete: Athlete) -> String {
        var parts: [String] = []
        if !athlete.username.isEmpty { parts.append("@\(athlete.username)") }
        parts.append(athlete.position.isEmpty ? "No preference" : athlete.position)
        if !athlete.managed { parts.append("Own login") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Add

    private var addButton: some View {
        SecondaryButton(label: "Add an athlete") {
            showAddAthlete = true
        }
    }

    // MARK: - Actions

    private var removeBinding: Binding<Bool> {
        Binding(
            get: { athleteToRemove != nil },
            set: { if !$0 { athleteToRemove = nil } }
        )
    }

    private func switchTo(_ athlete: Athlete) {
        switching = athlete.id
        withAnimation(DS.Motion.standardSpring) {
            family.setActive(athlete.id)
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        switching = nil
    }

    private func addAthlete(username: String, name: String, kit: String, position: String) {
        let athlete = family.addAthlete(username: username, name: name, kit: kit, position: position)
        // Best-effort remote enrollment under the parent's account + family.
        Task {
            guard let accountID = AuthService.shared.user?.id else { return }
            do {
                let fam = try await FamilyService.shared.ensureFamily(
                    ownerID: accountID,
                    name: family.householdName.isEmpty ? nil : family.householdName
                )
                try await FamilyService.shared.addManagedAthlete(
                    accountID: accountID,
                    familyID: fam?.id,
                    athlete: athlete
                )
            } catch {
                print("[Family] remote enrollment failed: \(error)")
            }
        }
    }

    private func remove(_ athlete: Athlete) {
        family.removeAthlete(id: athlete.id)
        athleteToRemove = nil
        Task {
            do { try await FamilyService.shared.removeAthlete(id: athlete.id) }
            catch { print("[Family] remote removal failed: \(error)") }
        }
    }
}

#Preview {
    NavigationStack {
        FamilyManagementView()
    }
    .preferredColorScheme(.dark)
}
