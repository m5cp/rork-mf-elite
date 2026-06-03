//
//  Discipline.swift
//  MFElite
//

import Foundation
import SwiftData

/// A top-level training pillar (Technical, Physical, Tactical, Psychological).
@Model
final class Discipline {
    @Attribute(.unique) var id: String
    var number: String          // "01".."04"
    var name: String
    var mark: String            // "square" | "triangle" | "diamond" | "circle"
    var tagline: String
    var blurb: String
    var media: String           // "drill" | "video"
    var sortIndex: Int
    @Relationship(deleteRule: .cascade) var categories: [Category]

    init(
        id: String,
        number: String,
        name: String,
        mark: String,
        tagline: String,
        blurb: String,
        media: String,
        sortIndex: Int,
        categories: [Category] = []
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.mark = mark
        self.tagline = tagline
        self.blurb = blurb
        self.media = media
        self.sortIndex = sortIndex
        self.categories = categories
    }
}
