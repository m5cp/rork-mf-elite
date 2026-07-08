//
//  TrainingQueue.swift
//  MFElite
//
//  An ordered run of drills played back-to-back inside a single session
//  (a single drill + its suggested follow-ups, a routine, or a custom workout).
//

import Foundation
import Observation

/// Estimated minutes for a sequence of drills: total drill time + 15s rest per
/// set gap, rounded to the nearest 5 minutes (minimum 5).
func estimatedSessionMinutes(forDrills drills: [Drill]) -> Int {
    let totalSec = drills.reduce(0) { acc, drill in
        acc + drill.durationSec + max(0, drill.sets - 1) * 15
    }
    let mins = Double(totalSec) / 60
    let rounded = (mins / 5).rounded() * 5
    return max(5, Int(rounded))
}

/// A drill resolved to its full navigation context (drill + parents).
struct DrillContext: Identifiable, Hashable {
    let drill: Drill
    let level: MasteryLevel
    let category: Category
    let discipline: Discipline

    var id: String { drill.id }
}

/// A compact record of a drill completed within the current session, used by
/// the end-of-session summary.
struct CompletedDrillSummary: Identifiable {
    let id = UUID()
    let title: String
    let disciplineMark: String
    let durationSec: Int
    let xp: Int
}

/// Drives an ordered, auto-advancing run of drills. The player never dismisses
/// and re-presents to move on — `advance()` swaps the active drill in place.
@MainActor
@Observable
final class TrainingQueue: Identifiable {
    let id = UUID()
    let items: [DrillContext]
    let source: SessionSource
    let sourceName: String?

    var currentIndex: Int = 0
    private(set) var completed: [CompletedDrillSummary] = []

    init(
        items: [DrillContext],
        source: SessionSource = .single,
        sourceName: String? = nil
    ) {
        self.items = items
        self.source = source
        self.sourceName = sourceName
    }

    /// The drill currently being played.
    var current: DrillContext? {
        items.indices.contains(currentIndex) ? items[currentIndex] : nil
    }

    /// The drill that will play after the current one, if any.
    var upNext: DrillContext? {
        items.indices.contains(currentIndex + 1) ? items[currentIndex + 1] : nil
    }

    var count: Int { items.count }

    /// 1-based position of the current drill.
    var position: Int { currentIndex + 1 }

    /// True when the current drill is the final one in the queue.
    var isLastDrill: Bool { currentIndex >= items.count - 1 }

    /// True when this run chains more than one drill (routine, workout, or a
    /// single start with suggested follow-ups).
    var isChained: Bool { count > 1 }

    /// Move to the next drill, if there is one.
    func advance() {
        guard currentIndex < items.count - 1 else { return }
        currentIndex += 1
    }

    /// Move back to the previous drill, if there is one.
    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    /// True when there is a drill before the current one.
    var hasPrevious: Bool { currentIndex > 0 }

    /// Record a finished drill for the end-of-session summary.
    func recordCompleted(_ summary: CompletedDrillSummary) {
        completed.append(summary)
    }
}
