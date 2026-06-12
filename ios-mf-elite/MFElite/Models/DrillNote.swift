//
//  DrillNote.swift
//  MFElite
//
//  One private player note per drill, keyed by drillID so it survives
//  curriculum re-seeds. Local-only — never sent anywhere, never logged.
//

import Foundation
import SwiftData

/// One private player note per drill, keyed by drillID so it survives re-seeds.
@Model
final class DrillNote {
    @Attribute(.unique) var drillID: String
    var text: String
    var updatedAt: Date

    init(drillID: String, text: String, updatedAt: Date = Date()) {
        self.drillID = drillID
        self.text = text
        self.updatedAt = updatedAt
    }
}
