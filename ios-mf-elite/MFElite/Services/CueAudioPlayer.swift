//
//  CueAudioPlayer.swift
//  MFElite
//
//  Plays the drill timer's audio cues (countdown beep, set-complete chime,
//  session-complete fanfare, rest start) through an always-on audio engine so
//  they keep sounding when the screen sleeps or the player switches to music or
//  another app mid-session. A low-volume silent loop keeps the audio session
//  alive in the background, which also keeps the drill timer ticking. Cues mix
//  politely with the player's own music instead of cutting it off.
//

import Foundation
import AVFoundation

@MainActor
final class CueAudioPlayer {
    static let shared = CueAudioPlayer()

    private let engine = AVAudioEngine()
    private let cueNode = AVAudioPlayerNode()
    private let keepAliveNode = AVAudioPlayerNode()

    private let sampleRate: Double = 44_100
    private let format: AVAudioFormat
    private var isConfigured = false
    private(set) var isSessionActive = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
            ?? AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    }

    // MARK: - Session lifecycle

    /// Begin an audio session for a live guided-timer drill. Safe to call
    /// repeatedly. The session keeps the app audible (and ticking) in the
    /// background until `endSession()` is called.
    func beginSession() {
        guard !isSessionActive else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            // `.playback` so the countdown is audible with the ringer off and
            // the timer keeps running with the screen asleep. `.mixWithOthers`
            // so the player's own music keeps going underneath.
            //
            // Deliberately NOT `.duckOthers`: ducking pulls their music down
            // for the WHOLE session, not just for the beep, which is most of
            // what "the app messes with my music" feels like. The cues are
            // short and bright enough to hear over a track at full volume.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            configureIfNeeded()
            if !engine.isRunning { try engine.start() }
            scheduleKeepAliveLoop()
            keepAliveNode.play()
            cueNode.play()
            isSessionActive = true
        } catch {
            isSessionActive = false
        }
    }

    /// End the audio session when the drill is logged or the player exits.
    func endSession() {
        guard isSessionActive else { return }
        stopCadence()
        cueNode.stop()
        keepAliveNode.stop()
        engine.stop()
        isSessionActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        // Hand the session back to the app-wide ambient default, so nothing
        // after this drill is running under a `.playback` category it no
        // longer needs.
        AppAudioSession.restoreMixingDefault()
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        engine.attach(cueNode)
        engine.attach(keepAliveNode)
        engine.connect(cueNode, to: engine.mainMixerNode, format: format)
        engine.connect(keepAliveNode, to: engine.mainMixerNode, format: format)
        isConfigured = true
    }

    // MARK: - Cues

    /// Short, bright tick used for the 3-2-1 countdown.
    func playCountdownBeep() {
        play(tone(frequency: 1_046, duration: 0.09, amplitude: 0.5))
    }

    /// A rising two-note chime when a set finishes.
    func playSetComplete() {
        play(sequence: [(784, 0.10), (1_046, 0.16)], amplitude: 0.55)
    }

    /// A fuller three-note flourish when the whole drill is logged.
    func playSessionComplete() {
        play(sequence: [(784, 0.10), (988, 0.10), (1_318, 0.22)], amplitude: 0.6)
    }

    /// A soft low cue marking the start of a rest period.
    func playRestStart() {
        play(tone(frequency: 523, duration: 0.18, amplitude: 0.45))
    }

    /// A dry, quiet tick for the per-second counter. Deliberately duller and
    /// softer than the 3-2-1 countdown beep — it fires up to once a second for
    /// the length of a set, so it has to sit under the player's music rather
    /// than compete with it.
    func playCounterTick() {
        play(tone(frequency: 660, duration: 0.035, amplitude: 0.22))
    }

    /// The cadence click. Two pitches so a runner can hear the downbeat: every
    /// `accentEvery` clicks is higher and slightly louder.
    func playCadenceClick(accented: Bool) {
        play(tone(frequency: accented ? 1_318 : 880,
                  duration: 0.03,
                  amplitude: accented ? 0.38 : 0.26))
    }

    // MARK: - Cadence

    private var cadenceTimer: Timer?
    private var cadenceBeat = 0

    /// Whether a cadence is currently running, so the UI can show the right control.
    private(set) var isCadenceRunning = false

    /// Start a metronome at `bpm`, accenting every `accentEvery` beats.
    ///
    /// Scheduled on the run loop in `.common` mode so it keeps time while the
    /// player is scrolling, and driven off the same mixing session as the cues —
    /// a cadence that stopped someone's music would be worse than no cadence.
    func startCadence(bpm: Int, accentEvery: Int = 4) {
        stopCadence()
        guard isSessionActive else { return }
        let clamped = min(240, max(30, bpm))
        let interval = 60.0 / Double(clamped)
        cadenceBeat = 0
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isCadenceRunning else { return }
                let accented = accentEvery > 1 && self.cadenceBeat % accentEvery == 0
                self.playCadenceClick(accented: accented)
                self.cadenceBeat &+= 1
            }
        }
        RunLoop.main.add(t, forMode: .common)
        cadenceTimer = t
        isCadenceRunning = true
        // Fire the downbeat immediately; a metronome that waits a full beat
        // before its first click feels broken.
        playCadenceClick(accented: accentEvery > 1)
        cadenceBeat = 1
    }

    func stopCadence() {
        cadenceTimer?.invalidate()
        cadenceTimer = nil
        cadenceBeat = 0
        isCadenceRunning = false
    }

    // MARK: - Synthesis

    private func play(_ buffer: AVAudioPCMBuffer) {
        guard isSessionActive else { return }
        cueNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    private func play(sequence notes: [(Double, Double)], amplitude: Float) {
        guard isSessionActive else { return }
        for (frequency, duration) in notes {
            cueNode.scheduleBuffer(tone(frequency: frequency, duration: duration, amplitude: amplitude),
                                   at: nil, options: [], completionHandler: nil)
        }
    }

    /// Build a single sine tone with a short attack/decay envelope to avoid clicks.
    private func tone(frequency: Double, duration: Double, amplitude: Float) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: max(1, frameCount))!
        buffer.frameLength = max(1, frameCount)
        guard let channel = buffer.floatChannelData?[0] else { return buffer }

        let total = Int(buffer.frameLength)
        let twoPiF = 2.0 * Double.pi * frequency
        let fade = max(1, total / 8)
        for i in 0..<total {
            let t = Double(i) / sampleRate
            var env = 1.0
            if i < fade { env = Double(i) / Double(fade) }
            else if i > total - fade { env = Double(total - i) / Double(fade) }
            channel[i] = Float(sin(twoPiF * t) * env) * amplitude
        }
        return buffer
    }

    /// A half-second of near-silence, looped, that keeps the audio session (and
    /// therefore the running timer) alive when the app is backgrounded.
    private func scheduleKeepAliveLoop() {
        let frameCount = AVAudioFrameCount(0.5 * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        if let channel = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) { channel[i] = 0.0 }
        }
        keepAliveNode.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
    }
}
