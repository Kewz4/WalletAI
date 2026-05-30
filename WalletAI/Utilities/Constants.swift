import Foundation

enum Constants {
    enum API {
        // Groq — free tier, no credit card (console.groq.com)
        static let groqBaseURL       = "https://api.groq.com/openai/v1"
        static let groqModel         = "llama-3.3-70b-versatile"
        static let groqChatModel     = "compound-beta"   // has built-in Groq web search
        static let groqKeyStorageKey = "walletai_groq_key"
    }

    enum Storage {
        static let onboardingKey = "hasCompletedOnboarding"
        static let preferredCurrencyKey = "preferredCurrency"
        static let biometricEnabledKey = "biometricEnabled"
        static let notificationsEnabledKey = "notificationsEnabled"
        static let themeKey        = "appTheme"
        static let colorSchemeKey  = "appColorScheme"
        static let personalityKey  = "appPersonality"
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
