import Foundation
import SwiftData

/// A player's enrollment in a program. Completed days are stored as "w-d" keys
/// (week index - day index, both 0-based), e.g. "0-1".
@Model
final class ProgramEnrollment {
    @Attribute(.unique) var programID: String
    var startedAt: Date
    var completedDayKeys: [String]

    init(programID: String, startedAt: Date = Date(), completedDayKeys: [String] = []) {
        self.programID = programID
        self.startedAt = startedAt
        self.completedDayKeys = completedDayKeys
    }

    static func key(week: Int, day: Int) -> String { "\(week)-\(day)" }
}
