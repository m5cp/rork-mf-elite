//
//  CaptionModerator.swift
//  MFElite
//
//  On-device caption safety check for the share flow. Fast local feedback before
//  a caption ever lands on a card: the caption is lowercased, split into word
//  tokens, and checked against a maintained blocklist of profanity / hate /
//  bullying / sexual terms. Multi-word phrases are matched as substrings; single
//  words are matched whole-word to avoid the "Scunthorpe" false-positive problem
//  (e.g. "class" must not trip on "ass").
//
//  This is the first of two layers described in the handoff. A server-side check
//  runs later in the share-link edge function before any link goes public; this
//  local pass gives the player immediate, friendly feedback in the caption sheet.
//

import Foundation

/// The result of moderating a caption.
enum CaptionModerationResult: Equatable {
    /// The caption is clean and may be used.
    case allowed
    /// The caption contains a blocked term; `word` is the offending match.
    case blocked(word: String)

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
}

/// Stateless on-device caption moderator.
enum CaptionModerator {
    /// The maximum caption length, matching the editor's field limit.
    static let maxLength = 40

    /// Runs the local blocklist check on `text`.
    ///
    /// Empty / whitespace-only captions are treated as allowed (there is nothing
    /// to place on the card). Matching is case-insensitive and diacritic- and
    /// separator-insensitive so simple obfuscations ("i.d.i.o.t", "hÀte") still
    /// resolve.
    static func moderate(_ text: String) -> CaptionModerationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .allowed }

        let normalized = normalize(trimmed)

        // Multi-word phrases: substring match on the normalized (space-collapsed) text.
        let spaced = " \(normalized) "
        for phrase in blockedPhrases where phrase.contains(" ") {
            if spaced.contains(" \(phrase) ") || normalized.contains(phrase) {
                return .blocked(word: phrase)
            }
        }

        // Single words: whole-token match to avoid false positives inside larger words.
        let tokens = normalized
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
        let tokenSet = Set(tokens)
        // Also build a separator-stripped run (handles "i.d.i.o.t" → "idiot").
        let collapsed = normalized.filter { $0.isLetter || $0.isNumber }

        for word in blockedWords {
            if tokenSet.contains(word) { return .blocked(word: word) }
            // Catch spaced-out obfuscation only for words long enough to be unambiguous.
            if word.count >= 4, collapsed == word { return .blocked(word: word) }
        }

        return .allowed
    }

    // MARK: - Normalization

    /// Lowercases, folds diacritics, and collapses runs of whitespace to single
    /// spaces so matching is resilient to accents and spacing.
    private static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let collapsed = folded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
    }

    // MARK: - Blocklist

    /// Multi-word blocked phrases (matched as substrings).
    private static let blockedPhrases: [String] = [
        "hot girl", "hot boy", "shut up", "kill yourself", "kill your self",
        "kys yourself", "go die", "hate you", "hate u",
    ]

    /// Single blocked words. Starter list from the design handoff (`share-data.jsx`)
    /// expanded with a maintained English profanity / hate / bullying / sexual list.
    /// Kept lowercase; matching normalizes case and diacritics.
    private static let blockedWords: Set<String> = [
        // ----- Starter list (handoff share-data.jsx) -----
        "hate", "kill", "die", "stupid", "idiot", "loser", "dumb", "ugly", "trash",
        "sexy", "nude", "naked", "kys", "suck", "fat", "racist", "nazi", "gun",
        "drugs", "damn", "hell",

        // ----- Profanity -----
        "fuck", "fucker", "fucking", "fucked", "motherfucker", "mofo",
        "shit", "shitty", "bullshit", "bs", "crap", "piss", "pissed",
        "ass", "asshole", "arse", "arsehole", "jackass", "dumbass",
        "bitch", "bitches", "bastard", "bugger", "wanker", "tosser",
        "prick", "douche", "douchebag", "twat", "git",

        // ----- Sexual / explicit -----
        "sex", "porn", "porno", "pornhub", "xxx", "nsfw", "boobs", "boob",
        "tits", "titties", "titty", "dick", "dicks", "cock", "cocks", "penis",
        "pussy", "vagina", "cunt", "cum", "cumming", "jizz", "horny", "orgasm",
        "blowjob", "handjob", "bj", "milf", "thot", "hoe", "slut", "slutty",
        "whore", "whores", "escort", "onlyfans", "stripper", "erotic",
        "hentai", "dildo", "boner",

        // ----- Hate / slurs / bullying -----
        "retard", "retarded", "spastic", "spaz", "cripple",
        "fag", "faggot", "fags", "dyke", "tranny",
        "nigger", "nigga", "niggas", "coon", "chink", "gook", "spic",
        "kike", "wetback", "beaner", "raghead", "paki", "wop",
        "hitler", "kkk", "genocide", "terrorist", "isis",
        "rape", "rapist", "molest", "pedo", "pedophile", "paedophile",

        // ----- Self-harm / violence -----
        "suicide", "kms", "cutter", "cutting", "hang", "hanging",
        "shoot", "shooter", "shooting", "murder", "murderer", "stab",
        "bomb", "bombing", "behead", "lynch",

        // ----- Drugs / illicit -----
        "cocaine", "coke", "heroin", "meth", "crack", "weed", "marijuana",
        "cannabis", "vape", "vaping", "juul", "cigarette", "cigarettes",
        "smoke", "smoking", "beer", "vodka", "whiskey", "alcohol", "drunk",
        "wasted", "high", "stoned", "molly", "ecstasy", "lsd", "xanax", "adderall",

        // ----- Bullying / demeaning -----
        "worthless", "pathetic", "freak", "weirdo", "creep", "creepy",
        "moron", "imbecile", "clown", "nerd", "dork", "geek", "reject",
        "ratchet", "nasty", "gross", "disgusting", "smelly", "stink",
        "noob", "scrub", "garbage", "useless", "failure", "quitter",
    ]
}
