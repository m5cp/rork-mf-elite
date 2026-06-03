//
//  Category.swift
//  MFElite
//

import Foundation
import SwiftData

/// A skill category within a discipline (e.g. Ball Mastery, Speed).
@Model
final class Category {
    @Attribute(.unique) var id: String
    var letter: String          // "A".."E"
    var name: String
    var focus: String
    var certName: String
    var sortIndex: Int
    @Relationship(deleteRule: .cascade) var levels: [MasteryLevel]

    init(
        id: String,
        letter: String,
        name: String,
        focus: String,
        certName: String,
        sortIndex: Int,
        levels: [MasteryLevel] = []
    ) {
        self.id = id
        self.letter = letter
        self.name = name
        self.focus = focus
        self.certName = certName
        self.sortIndex = sortIndex
        self.levels = levels
    }
}
