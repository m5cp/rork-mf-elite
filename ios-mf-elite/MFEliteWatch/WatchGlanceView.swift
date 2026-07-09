//
//  WatchGlanceView.swift
//  MFEliteWatch
//
//  The wrist glance: today's session, activity rings, streak, and steps.
//  Tapping "Start" launches the on-wrist session runner; "Quick-log" marks
//  the whole session done without running the timers.
//

import SwiftUI

struct WatchGlanceView: View {
    @Environment(WatchConnectivityReceiver.self) private var connectivity
    @State private var runningSession = false
    @State private var justLogged = false

    private var glance: WatchGlanceData { connectivity.glance }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ringsRow

                    Divider()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(glance.sessionEyebrow.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(glance.sessionTitle)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(2)
                        if !glance.drills.isEmpty {
                            Text("\(glance.drills.count) drills · \(glance.sessionMinutes) min")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !glance.drills.isEmpty {
                        Button {
                            runningSession = true
                        } label: {
                            Label("Start", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.green)

                        Button {
                            quickLog()
                        } label: {
                            Label(justLogged ? "Logged!" : "Quick-log", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(justLogged)
                    } else {
                        Text("Open MF Elite on your phone to sync today's session.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    stepsRow
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("MF Elite")
            .fullScreenCover(isPresented: $runningSession) {
                WatchSessionRunnerView(drills: glance.drills, sourceName: glance.sessionTitle)
            }
        }
    }

    private var ringsRow: some View {
        HStack(spacing: 12) {
            ringGauge(progress: Double(glance.trainMinutes) / Double(max(1, glance.trainGoalMinutes)), color: .white)
            ringGauge(progress: Double(glance.drillCount) / Double(max(1, glance.drillGoal)), color: .white.opacity(0.7))
            ringGauge(progress: Double(glance.mindCount) / Double(max(1, glance.mindGoal)), color: .white.opacity(0.45))

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("\(glance.streak)")
                        .font(.system(size: 15, weight: .bold))
                }
                Text("\(glance.xp) XP")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func ringGauge(progress: Double, color: Color) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(1, progress))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 26, height: 26)
    }

    private var stepsRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.walk")
                .font(.system(size: 12, weight: .semibold))
            Text("\(glance.steps.formatted()) / \(glance.stepGoal.formatted()) steps")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private func quickLog() {
        WKInterfaceDeviceProxy.playSuccess()
        connectivity.sendQuickLog(
            drillIDs: glance.drills.map(\.id),
            sourceName: glance.sessionTitle
        )
        justLogged = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { runningSession = false }
    }
}

#Preview {
    WatchGlanceView()
        .environment(WatchConnectivityReceiver.shared)
}
