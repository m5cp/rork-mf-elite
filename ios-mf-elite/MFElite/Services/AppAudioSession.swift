//
//  AppAudioSession.swift
//  MFElite
//
//  One decision, made once at launch: MF Elite never takes the user's audio.
//
//  iOS defaults an app to `.soloAmbient`, which interrupts whatever else is
//  playing the moment anything in the app activates the session — a demo video,
//  a cue, a system sound. For a training app that is exactly backwards. Players
//  train to their own music or a podcast, and an app that kills it the moment
//  they open a drill is an app they stop opening.
//
//  `.ambient` + `.mixWithOthers` is the opposite default: it never interrupts,
//  it never ducks, and it obeys the ringer switch — silent means silent, which
//  is what a player expects from an app that is not a media player.
//
//  Two places deliberately override this:
//
//    * `CueAudioPlayer` raises the category to `.playback` for the duration of
//      a guided drill, so the countdown is still audible with the ringer off
//      and the timer keeps running with the screen asleep. It keeps
//      `.mixWithOthers`, so the music continues underneath.
//    * `DrillDemoVideoView` mutes its player by default, because a demo video's
//      own audio is the one thing here that genuinely competes with a podcast.
//

import AVFoundation

enum AppAudioSession {

    /// Install the non-interrupting default. Called once, at launch, before
    /// anything has a chance to activate a session of its own.
    static func configureForMixing() {
        let session = AVAudioSession.sharedInstance()
        // Not activated here on purpose. Setting the category is enough to
        // decide how we behave when something later does activate; activating
        // an empty session at launch is exactly the interruption we're avoiding.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }

    /// Put the ambient default back after a drill's `.playback` session ends,
    /// so the rest of the app returns to never interrupting anything.
    static func restoreMixingDefault() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    }

    /// True when something else — Music, a podcast, another app — is playing.
    /// Used to decide whether a demo video should start muted.
    static var isOtherAudioPlaying: Bool {
        AVAudioSession.sharedInstance().isOtherAudioPlaying
    }
}
