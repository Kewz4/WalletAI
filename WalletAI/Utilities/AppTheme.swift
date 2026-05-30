import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case `default` = "default"
    case girly     = "girly"
    case lively    = "lively"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .girly:   return "Girly"
        case .lively:  return "Lively"
        }
    }

    var emoji: String {
        switch self {
        case .default: return "💼"
        case .girly:   return "🎀"
        case .lively:  return "🌈"
        }
    }

    var primaryColor: Color {
        switch self {
        case .default: return Color("WalletPrimary")
        case .girly:   return Color(hex: "#E91E8C")!   // hot pink
        case .lively:  return Color(hex: "#FF6B35")!   // vivid orange
        }
    }

    var accentColor: Color {
        switch self {
        case .default: return Color("WalletAccent")
        case .girly:   return Color(hex: "#FF85C2")!   // pastel pink
        case .lively:  return Color(hex: "#FFD23F")!   // golden yellow
        }
    }

    // AI system-prompt personality suffix
    var aiPersonality: String {
        switch self {
        case .default, .lively:
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

    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: Constants.Storage.themeKey) ?? "default") ?? .default
    }
}
