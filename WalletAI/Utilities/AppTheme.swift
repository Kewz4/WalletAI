import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case skyBlue  = "default"    // legacy default rawValue
    case rose     = "girly"      // legacy girly rawValue (keep for backward compat)
    case babyPink = "babyPink"
    case lavender = "lavender"
    case mint     = "mint"
    case coral    = "coral"
    case ocean    = "ocean"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skyBlue:  return "Indigo"
        case .rose:     return "Rose"
        case .babyPink: return "Baby Pink"
        case .lavender: return "Lavender"
        case .mint:     return "Mint"
        case .coral:    return "Coral"
        case .ocean:    return "Ocean"
        }
    }

    var primaryColor: Color {
        switch self {
        case .skyBlue:  return Color(hex: "#6366F1")!
        case .rose:     return Color(hex: "#EC4899")!
        case .babyPink: return Color(hex: "#FF85A1")!
        case .lavender: return Color(hex: "#8B5CF6")!
        case .mint:     return Color(hex: "#10B981")!
        case .coral:    return Color(hex: "#F97316")!
        case .ocean:    return Color(hex: "#0EA5E9")!
        }
    }

    var accentColor: Color {
        switch self {
        case .skyBlue:  return Color(hex: "#818CF8")!
        case .rose:     return Color(hex: "#F472B6")!
        case .babyPink: return Color(hex: "#FFB3C6")!
        case .lavender: return Color(hex: "#A78BFA")!
        case .mint:     return Color(hex: "#34D399")!
        case .coral:    return Color(hex: "#FB923C")!
        case .ocean:    return Color(hex: "#38BDF8")!
        }
    }

    static var current: AppTheme {
        AppTheme(rawValue: UserDefaults.standard.string(forKey: Constants.Storage.themeKey) ?? "default") ?? .skyBlue
    }
}
