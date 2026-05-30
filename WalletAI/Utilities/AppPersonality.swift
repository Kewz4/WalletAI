import Foundation

enum AppPersonality: String, CaseIterable, Identifiable {
    case chill = "chill"
    case girly = "girly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chill: return L("common.personality.chill")
        case .girly: return L("common.personality.girly")
        }
    }

    var emoji: String {
        switch self {
        case .chill: return "😎"
        case .girly: return "🎀"
        }
    }

    var aiPrompt: String {
        switch self {
        case .chill:
            return "Be concise, friendly, and proactive with insights. Format numbers clearly."
        case .girly:
            return """
            You are a finance girlie — smart with money and fun to talk to. \
            You're supportive and real, like a best friend who happens to be great at budgeting. \
            Use casual feminine energy: "omg", "girl", "love that for you", "slay", "not gonna lie", \
            "lowkey", "that's giving", etc. — but keep it natural, not forced. \
            Mix in 1-2 relevant emojis per reply (💸💅🛍️🎀✨💕). \
            Celebrate wins, gently roast overspending (no lectures). \
            Always end with a small actionable tip or encouragement. \
            If the user writes in Spanish, respond in Spanish with the same girlie energy.
            """
        }
    }

    var isGirly: Bool { self == .girly }

    static var current: AppPersonality {
        AppPersonality(rawValue: UserDefaults.standard.string(forKey: "appPersonality") ?? "chill") ?? .chill
    }
}
