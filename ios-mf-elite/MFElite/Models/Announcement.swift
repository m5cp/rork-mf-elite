//
//  Announcement.swift
//  MFElite
//
//  A local cache of the most recent active team announcement published by a
//  coach. Mirrors a row from the remote `announcements` table so the Today
//  banner renders even offline. Purely additive and read-only on the player
//  side: this never touches the curriculum, progress, or history.
//

import Foundation
import SwiftData

/// One coach team announcement, cached locally for the Today banner.
@Model
final class Announcement {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var createdAt: Date

    init(id: UUID, title: String, body: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
    }
}
