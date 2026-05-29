import SwiftUI
import SwiftData

@main
struct WalletAIApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Transaction.self,
                Category.self,
                Budget.self,
                AIConversation.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
            SeedData.seedIfNeeded(container: container)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    @AppStorage(Constants.Storage.themeKey)       private var themeKey        = "default"
    @AppStorage(Constants.Storage.colorSchemeKey) private var colorSchemeRaw  = "system"

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .preferredColorScheme(preferredColorScheme)
                .task { await NotificationService.shared.requestPermission() }
                // Re-create the entire view hierarchy when the theme changes so
                // all Color.walletPrimary / walletAccent references pick up new values.
                .id(themeKey)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}
