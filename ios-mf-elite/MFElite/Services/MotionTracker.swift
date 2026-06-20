//
//  MotionTracker.swift
//  MFElite
//
//  Hands-free motion features for a live drill: a rep/touch counter (peak
//  detection on device-motion acceleration), shake-to-advance (a strong,
//  deliberate jolt), a smoothed movement-intensity meter, and a step count via
//  CMPedometer. All optional and gated by settings; degrades silently when the
//  hardware or permission is unavailable.
//

import Foundation
import Observation
import CoreMotion

@MainActor
@Observable
final class MotionTracker {
    static let shared = MotionTracker()

    /// Live rep/touch tally for the current set.
    private(set) var repCount: Int = 0
    /// Smoothed 0–1 movement intensity for the live meter.
    private(set) var intensity: Double = 0
    /// Steps counted during the active session.
    private(set) var stepCount: Int = 0
    /// Whether device motion is currently being read.
    private(set) var isRunning: Bool = false

    /// Fired once when a deliberate shake is detected (debounced).
    var onShake: (() -> Void)?

    private let motion = CMMotionManager()
    private let pedometer = CMPedometer()

    // Peak-detection state for rep counting.
    private var lastPeakTime: TimeInterval = 0
    private var aboveThreshold = false
    // Shake debounce.
    private var lastShakeTime: TimeInterval = 0
    // Feature flags for the running session.
    private var wantsReps = false
    private var wantsShake = false
    private var wantsMovement = false
    // Average-intensity accumulation for the saved summary.
    private var intensitySum: Double = 0
    private var intensitySamples: Int = 0

    private init() {}

    /// True when the device can report motion at all.
    var isAvailable: Bool { motion.isDeviceMotionAvailable }

    /// Average movement intensity (0–1) across the session, for the log entry.
    var averageIntensity: Double {
        intensitySamples > 0 ? intensitySum / Double(intensitySamples) : 0
    }

    // MARK: - Lifecycle

    func start(countReps: Bool, detectShake: Bool, trackMovement: Bool) {
        guard isAvailable, !isRunning else { return }
        guard countReps || detectShake || trackMovement else { return }

        repCount = 0
        intensity = 0
        stepCount = 0
        aboveThreshold = false
        lastPeakTime = 0
        lastShakeTime = 0
        intensitySum = 0
        intensitySamples = 0
        wantsReps = countReps
        wantsShake = detectShake
        wantsMovement = trackMovement
        isRunning = true

        motion.deviceMotionUpdateInterval = 1.0 / 40.0
        motion.startDeviceMotionUpdates(to: .main) { data, _ in
            guard let data else { return }
            let a = data.userAcceleration
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            let timestamp = data.timestamp
            Task { @MainActor in
                MotionTracker.shared.ingest(magnitude: magnitude, timestamp: timestamp)
            }
        }

        if trackMovement, CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { data, _ in
                guard let steps = data?.numberOfSteps.intValue else { return }
                Task { @MainActor in MotionTracker.shared.stepCount = steps }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        onShake = nil
        motion.stopDeviceMotionUpdates()
        pedometer.stopUpdates()
    }

    /// Reset the per-set rep tally (e.g. when a new set begins).
    func resetReps() {
        repCount = 0
        aboveThreshold = false
    }

    // MARK: - Processing

    private func ingest(magnitude: Double, timestamp: TimeInterval) {
        guard isRunning else { return }

        if wantsMovement {
            let normalized = min(1.0, magnitude / 2.0)
            intensity = intensity * 0.9 + normalized * 0.1
            intensitySum += normalized
            intensitySamples += 1
        }

        if wantsShake, magnitude > 2.2, timestamp - lastShakeTime > 1.2 {
            lastShakeTime = timestamp
            onShake?()
        }

        if wantsReps {
            let high = 0.85
            let low = 0.45
            if !aboveThreshold, magnitude > high, timestamp - lastPeakTime > 0.25 {
                aboveThreshold = true
                lastPeakTime = timestamp
                repCount += 1
            } else if aboveThreshold, magnitude < low {
                aboveThreshold = false
            }
        }
    }
}
