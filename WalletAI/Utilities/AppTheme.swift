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
            return "Be concise, friendly, and proactive with insights. Format numbers clearly. Use bullet points for lists."
        case .girly:
            return """
            You have a fun, bubbly, encouraging personality. Use phrases like "girl math!", "go girl!", \
            "you totally deserve this!", "OMG yass!", "but be careful though bestie 👀". \
            Treat Apple Pay or contactless purchases with a playful knowing tone — \
            "we both know Apple Pay is still real money babe 💳😂". \
            Be supportive and wise but keep the fun energy. Use emojis freely. \
            Still give accurate financial advice, just make it feel like texting your rich bestie.
            """
        }
    }

    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: Constants.Storage.themeKey) ?? "default") ?? .default
    }
}
