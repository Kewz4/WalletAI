import Foundation

enum Constants {
    enum API {
        // Gemini (free tier — get key at aistudio.google.com)
        static let geminiBaseURL       = "https://generativelanguage.googleapis.com/v1beta/openai"
        static let geminiModel         = "gemini-2.0-flash"
        static let geminiKeyStorageKey = "walletai_gemini_key"

        // DeepSeek (legacy — kept for users who already have a key)
        static let deepSeekBaseURL       = "https://api.deepseek.com/v1"
        static let deepSeekModel         = "deepseek-chat"
        static let deepSeekKeyStorageKey = "walletai_deepseek_key"
    }

    enum Storage {
        static let onboardingKey = "hasCompletedOnboarding"
        static let preferredCurrencyKey = "preferredCurrency"
        static let biometricEnabledKey = "biometricEnabled"
        static let notificationsEnabledKey = "notificationsEnabled"
        static let themeKey        = "appTheme"
        static let colorSchemeKey  = "appColorScheme"
    }

    enum Design {
        static let cornerRadius: CGFloat = 20
        static let smallCornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let largePadding: CGFloat = 24
        static let iconSize: CGFloat = 44
        static let tabBarHeight: CGFloat = 83
        static let glassMergeSpacing: CGFloat = 12
    }

    enum Limits {
        static let maxTransactionTitle = 100
        static let maxNoteLength = 500
        static let maxCategories = 50
        static let aiMessageHistory = 20
    }
}

let supportedCurrencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "BRL", "MXN", "KRW"]
