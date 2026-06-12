//
//  WorkoutShareView.swift
//  MFElite
//
//  A sheet that presents a clean, scannable share card for a custom workout:
//  the MF logo mark, workout name, drill/time summary and a QR code that
//  encodes the workout as an mfelite:// link. Can be exported to an image and
//  handed to the native share sheet.
//

import SwiftUI

/// Lightweight description of a workout to share, decoupled from SwiftData.
struct ShareableWorkout: Identifiable {
    let id: UUID
    let title: String
    let drillIDs: [String]
    let drillCount: Int
    let minutes: Int
}

struct WorkoutShareView: View {
    let workout: ShareableWorkout

    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: ShareableImage?
    @State private var isExporting = false

    private var shareURL: URL? {
        WorkoutShare.url(for: workout.title, drillIDs: workout.drillIDs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.s24) {
                    shareCard
                        .raisedElevation()
                        .padding(.top, DS.Spacing.s8)

                    PrimaryButton(label: isExporting ? "Preparing…" : "Share workout") {
                        exportAndShare()
                    }
                    .padding(.horizontal, DS.Spacing.s8)

                    Text("Anyone with MF Elite can scan this code to get this exact workout on their phone.")
                        .style(.foot)
                        .foregroundStyle(DS.Colors.Ink.quaternary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.s16)
                }
                .padding(.horizontal, DS.Spacing.s20)
                .padding(.bottom, DS.Spacing.s32)
            }
            .background(DS.Colors.Bg.base)
            .scrollIndicators(.hidden)
            .navigationTitle("Share Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.Ink.primary)
                }
            }
            .sheet(item: $shareImage) { item in
                ShareSheet(items: [item.image])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    /// The renderable card. Light theme so the QR scans reliably.
    private var shareCard: some View {
        VStack(spacing: DS.Spacing.s20) {
            Image("mf-logo-black")
                .resizable()
                .scaledToFit()
                .frame(height: 28)

            VStack(spacing: DS.Spacing.s4) {
                Text(workout.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                Text("\(workout.drillCount) drills · ~\(workout.minutes) min")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.5))
            }

            qrView

            Text("Scan with MF Elite to get this workout.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.black.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(DS.Spacing.s24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    @ViewBuilder
    private var qrView: some View {
        if let url = shareURL, let qr = WorkoutShare.qrImage(for: url) {
            Image(uiImage: qr)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .padding(DS.Spacing.s16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.black.opacity(0.08), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 20)
                .fill(.black.opacity(0.05))
                .frame(width: 220, height: 220)
                .overlay(
                    Text("Couldn’t build code")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.black.opacity(0.4))
                )
        }
    }

    private func exportAndShare() {
        guard !isExporting else { return }
        isExporting = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let renderer = ImageRenderer(content: shareCard.frame(width: 360))
        renderer.scale = 3
        renderer.isOpaque = true
        isExporting = false
        if let image = renderer.uiImage {
            shareImage = ShareableImage(image: image)
        }
    }
}
