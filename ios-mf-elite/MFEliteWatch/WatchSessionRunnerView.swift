//
//  WatchSessionRunnerView.swift
//  MFEliteWatch
//
//  On-wrist session runner: steps through today's drills with a simple
//  work/rest timer per set, haptics on every transition. Finishing the last
//  drill (or tapping "Finish early") sends the completed drills back to the
//  phone via WatchConnectivityReceiver.sendQuickLog, which logs them through
//  the same pipeline as a phone-side quick log.
//

import SwiftUI

struct WatchSessionRunnerView: View {
    let drills: [WatchDrillItem]
    let sourceName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(WatchConnectivityReceiver.self) private var connectivity

    @State private var drillIndex = 0
    @State private var setIndex = 0
    @State private var phase: Phase = .work
    @State private var remaining: Int = 0
    @State private var timer: Timer?
    @State private var completedIDs: [String] = []
    @State private var isDone = false

    private enum Phase { case work, rest }

    private var currentDrill: WatchDrillItem? {
        drills.indices.contains(drillIndex) ? drills[drillIndex] : nil
    }

    var body: some View {
        VStack(spacing: 8) {
            if isDone {
                doneView
            } else if let drill = currentDrill {
                VStack(spacing: 4) {
                    Text(phase == .work ? "WORKING" : "REST")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(phase == .work ? .green : .orange)
                    Text(drill.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text("Set \(setIndex + 1) of \(drill.sets)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text("\(remaining)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                HStack(spacing: 8) {
                    Button("Skip") { advance() }
                        .tint(.gray)
                    Button("Finish early") { finishSession() }
                        .tint(.red)
                }
                .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 4)
        .onAppear { startDrill() }
        .onDisappear { timer?.invalidate() }
    }

    private var doneView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
            Text("Session logged")
                .font(.system(size: 15, weight: .bold))
            Text("\(completedIDs.count) drills · synced to your phone")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
        }
    }

    private func startDrill() {
        guard let drill = currentDrill else { finishSession(); return }
        phase = .work
        remaining = drill.workSec
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in tick() }
        }
    }

    private func tick() {
        guard remaining > 0 else {
            transition()
            return
        }
        remaining -= 1
        if remaining == 0 { transition() }
    }

    private func transition() {
        guard let drill = currentDrill else { return }
        WKInterfaceDeviceProxy.playClick()
        switch phase {
        case .work:
            if setIndex < drill.sets - 1 {
                phase = .rest
                remaining = drill.restSec
            } else {
                completedIDs.append(drill.id)
                advance()
                return
            }
        case .rest:
            setIndex += 1
            phase = .work
            remaining = drill.workSec
        }
        startTimer()
    }

    private func advance() {
        timer?.invalidate()
        if let drill = currentDrill, !completedIDs.contains(drill.id) {
            completedIDs.append(drill.id)
        }
        setIndex = 0
        drillIndex += 1
        if drillIndex >= drills.count {
            finishSession()
        } else {
            startDrill()
        }
    }

    private func finishSession() {
        timer?.invalidate()
        WKInterfaceDeviceProxy.playSuccess()
        if !completedIDs.isEmpty {
            connectivity.sendQuickLog(drillIDs: completedIDs, sourceName: sourceName)
        }
        isDone = true
    }
}

#Preview {
    WatchSessionRunnerView(
        drills: [WatchDrillItem(id: "1", title: "Toe Taps", sets: 2, workSec: 20, restSec: 10)],
        sourceName: "Preview"
    )
    .environment(WatchConnectivityReceiver.shared)
}
