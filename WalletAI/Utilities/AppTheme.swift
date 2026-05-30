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
            return "Be warm and friendly like a smart bestie who knows finance. Use occasional feminine warmth but no cringe. Max 1 emoji per reply. You can reply in Spanish if the user writes in Spanish."
        }
    }

    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: Constants.Storage.themeKey) ?? "default") ?? .default
    }
}
