//
//  MFEliteWatchApp.swift
//  MFEliteWatch
//

import SwiftUI

@main
struct MFEliteWatchApp: App {
    @State private var connectivity = WatchConnectivityReceiver.shared

    var body: some Scene {
        WindowGroup {
            WatchGlanceView()
                .environment(connectivity)
                .onAppear { connectivity.activate() }
        }
    }
}
