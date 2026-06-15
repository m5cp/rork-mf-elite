import Foundation

struct ProgramDay: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let drillIDs: [String] // empty == Rest day
    var isRest: Bool { drillIDs.isEmpty }
}

struct ProgramWeek: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let days: [ProgramDay]
}

struct TrainingProgram: Identifiable, Hashable {
    let id: String
    let title: String
    let tag: String
    let blurb: String
    let weeks: [ProgramWeek]

    var totalDays: Int { weeks.reduce(0) { $0 + $1.days.filter { !$0.isRest }.count } }
}

enum ProgramCatalog {
    static let all: [TrainingProgram] = [firstTouchBlock, speedAgilityBlock]

    static let firstTouchBlock = TrainingProgram(
        id: "first-touch-6wk",
        title: "6-Week First Touch Block",
        tag: "TECHNICAL",
        blurb: "Progress from wall passes to first touch under pressure. Builds toward First Touch Certified.",
        weeks: [
            ProgramWeek(title: "Week 1 — Foundations", days: [
                ProgramDay(title: "Wall Pass Foundations", drillIDs: ["tech-b-1-1", "tech-b-1-2", "tech-b-1-3"]),
                ProgramDay(title: "Control Basics", drillIDs: ["tech-b-1-4", "tech-b-2-1"]),
                ProgramDay(title: "Quick Feet", drillIDs: ["phys-a-1-1", "phys-a-1-2"]),
                ProgramDay(title: "Rest", drillIDs: [])
            ]),
            ProgramWeek(title: "Week 2 — Directional Touch", days: [
                ProgramDay(title: "Directional Touch", drillIDs: ["tech-b-2-1", "tech-b-2-2", "tech-b-2-3"]),
                ProgramDay(title: "Receive & Pass", drillIDs: ["tech-b-2-4", "tech-b-1-4"]),
                ProgramDay(title: "Focus", drillIDs: ["psy-b-1-1", "psy-b-1-2"]),
                ProgramDay(title: "Rest", drillIDs: [])
            ]),
            ProgramWeek(title: "Week 3 — Turning & Receiving", days: [
                ProgramDay(title: "Check & Receive", drillIDs: ["tech-b-3-1", "tech-b-3-2"]),
                ProgramDay(title: "Half-Turn Mastery", drillIDs: ["tech-b-3-3", "tech-b-3-4"]),
                ProgramDay(title: "Agility Support", drillIDs: ["phys-b-1-1", "phys-b-1-2"]),
                ProgramDay(title: "Rest", drillIDs: [])
            ]),
            ProgramWeek(title: "Week 4 — Aerial Control", days: [
                ProgramDay(title: "Aerial Control", drillIDs: ["tech-b-4-2", "tech-b-4-3", "tech-b-4-4"]),
                ProgramDay(title: "Juggle to Pass", drillIDs: ["tech-b-4-1"]),
                ProgramDay(title: "Composure", drillIDs: ["psy-b-2-1", "psy-b-2-2"]),
                ProgramDay(title: "Rest", drillIDs: [])
            ]),
            ProgramWeek(title: "Week 5 — Touch Under Pressure", days: [
                ProgramDay(title: "Pressure Touch", drillIDs: ["tech-b-5-1", "tech-b-5-2"]),
                ProgramDay(title: "Game-Speed Touch", drillIDs: ["tech-b-5-3", "tech-b-5-4"]),
                ProgramDay(title: "Speed", drillIDs: ["phys-a-2-1", "phys-a-2-2"]),
                ProgramDay(title: "Rest", drillIDs: [])
            ]),
            ProgramWeek(title: "Week 6 — Mastery", days: [
                ProgramDay(title: "First Touch Gauntlet", drillIDs: ["tech-b-5-1", "tech-b-5-4", "tech-b-3-2"]),
                ProgramDay(title: "Full Touch Session", drillIDs: ["tech-b-2-1", "tech-b-4-1", "tech-b-5-3"]),
                ProgramDay(title: "Cert Push", drillIDs: ["tech-b-5-2", "tech-b-5-4"])
            ])
        ]
    )

    static let speedAgilityBlock = TrainingProgram(
        id: "speed-agility-4wk",
        title: "4-Week Speed & Agility Block",
        tag: "PHYSICAL",
        blurb: "Sprint mechanics to top speed. Builds toward Speed & Agility Certified.",
        weeks: [
            ProgramWeek(title: "Week 1 — Mechanics", days: [
                ProgramDay(title: "Sprint Mechanics", drillIDs: ["phys-a-1-1", "phys-a-1-2", "phys-a-1-3"]),
                ProgramDay(title: "Balance & COD", drillIDs: ["phys-a-1-4", "phys-b-1-1"]),
                ProgramDay(title: "Shuffle & Shuttle", drillIDs: ["phys-b-1-2", "phys-b-1-3"]),
                ProgramDay(title: "Rest", drillIDs: [])
            ]),
            ProgramWeek(title: "Week 2 — Acceleration", days: [
                ProgramDay(title: "Sprint Starts", drillIDs: ["phys-a-2-1", "phys-a-2-2", "phys-a-2-4"]),
                ProgramDay(title: "Sprint + Ball", drillIDs: ["phys-a-2-3", "phys-b-1-4"]),
                ProgramDay(title: "Power", drillIDs: ["phys-b-2-1", "phys-b-2-2"]),
                ProgramDay(title: "Rest", drillIDs: [])
            ]),
            ProgramWeek(title: "Week 3 — Agility & Power", days: [
                ProgramDay(title: "Shuttle Speed", drillIDs: ["phys-a-3-1", "phys-a-3-2"]),
                ProgramDay(title: "Agility Runs", drillIDs: ["phys-a-3-3", "phys-a-3-4"]),
                ProgramDay(title: "Plyometrics", drillIDs: ["phys-b-2-3", "phys-b-3-1"]),
                ProgramDay(title: "Rest", drillIDs: [])
            ]),
            ProgramWeek(title: "Week 4 — Top Speed", days: [
                ProgramDay(title: "Quick Feet", drillIDs: ["phys-a-4-1", "phys-a-4-2"]),
                ProgramDay(title: "Circuits", drillIDs: ["phys-a-4-3", "phys-a-4-4"]),
                ProgramDay(title: "Advanced Sprint", drillIDs: ["phys-a-5-1", "phys-a-5-4"])
            ])
        ]
    )

    static func program(id: String) -> TrainingProgram? { all.first { $0.id == id } }
}
