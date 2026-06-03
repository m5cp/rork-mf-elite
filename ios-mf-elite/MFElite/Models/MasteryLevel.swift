//
//  MasteryLevel.swift
//  MFElite
//

import Foundation
import SwiftData

/// A level within a category, grouping a set of drills under a theme.
@Model
final class MasteryLevel {
    @Attribute(.unique) var id: String
    var number: Int
    var name: String
    var theme: String
    var sortIndex: Int
    @Relationship(deleteRule: .cascade) var drills: [Drill]

    init(
        id: String,
        number: Int,
        name: String,
        theme: String,
        sortIndex: Int,
        drills: [Drill] = []
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.theme = theme
        self.sortIndex = sortIndex
        self.drills = drills
    }
}
