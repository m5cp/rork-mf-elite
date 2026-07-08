//
//  DailyQuotes.swift
//  MFElite
//
//  The shared daily-quote source: one rotating quote per calendar day, used on
//  the session-complete screen (and anywhere else a "standard" line is needed).
//

import Foundation

enum DailyQuotes {
    static let all: [String] = [
        "Full effort is the only standard.",
        "The ball doesn't care about yesterday.",
        "Train like you've never won. Play like you've never lost.",
        "Discipline is choosing what you want most over what you want now.",
        "Every touch is a chance to improve.",
        "Champions are built in the sessions nobody sees.",
        "Your feet are your tools. Sharpen them daily.",
        "Pressure is a privilege.",
        "The difference between good and great is one more rep.",
        "Control the ball. Control the game.",
        "Do it when you don't feel like it. That's the edge.",
        "Touch the ball every single day. No exceptions.",
        "You are what you repeat.",
        "Small sessions, done daily, beat long sessions done occasionally.",
        "The best players in the world were once where you are now.",
        "Your weak foot is not optional. It is a weapon waiting to be built.",
        "Speed without control is just chaos.",
        "Every rep matters. Even the ones nobody sees.",
        "Train like you play. Play like you train.",
        "Focus is a skill. Practice it.",
        "The player who works hardest in the off-season wins in the season.",
        "Master the basics. Then master them again.",
        "Composure under pressure is trained, not given.",
        "Your body follows your mind. Think sharp, move sharp.",
        "Nobody remembers the excuses. They remember the results.",
        "There is no substitute for ball time.",
        "Be the player that coaches trust in the big moments.",
        "You control two things: your effort and your attitude.",
        "Your first touch determines everything that follows.",
        "Champions are built in the dark. Keep training.",
        "Talent is common. Discipline is rare.",
        "You don't rise to the occasion. You fall to the level of your training.",
        "Play with purpose. Every touch has intention.",
        "Rest is part of the process. Recover well.",
        "Mental strength is the most underrated skill in soccer.",
        "Be coachable. The best players always are.",
        "Consistency beats intensity. Show up every day.",
        "Play the game in your head before you play it on the pitch.",
        "Your position is earned. Never stop earning it.",
        "The ball moves faster than your feet. Think ahead.",
        "Make the simple pass. Make it perfectly.",
        "Watch the game. Study the game. Live the game.",
        "Your body is your tool. Respect it. Fuel it. Train it.",
        "The difference between a pass and a great pass is timing.",
        "Soccer is a thinking game played with your feet.",
        "Today's session is tomorrow's instinct.",
        "You miss 100% of the reps you skip.",
        "A strong mind controls a tired body.",
        "The pitch doesn't owe you anything. Earn every yard.",
        "Confidence comes from preparation. Prepare.",
        "Vision is seeing what others don't. Scan more.",
        "Movement off the ball is where games are won.",
        "Every champion was once a beginner who refused to quit.",
        "The players who last are the ones who love the process.",
        "Mistakes are data. Learn from every one.",
        "Be the hardest worker on the pitch. Every single time.",
        "Practice doesn't make perfect. Perfect practice makes perfect.",
        "Speed of thought beats speed of feet.",
        "Stay hungry. Stay humble. Stay sharp.",
        "The grind is the glory. Love the work."
    ]

    /// Today's quote — stable across the day, rotating daily.
    static var today: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return all[(dayOfYear - 1) % all.count]
    }
}
