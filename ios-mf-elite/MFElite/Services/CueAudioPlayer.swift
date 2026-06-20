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
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
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
        cueNode.stop()
        keepAliveNode.stop()
        engine.stop()
        isSessionActive = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
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
