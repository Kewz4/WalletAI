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

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .task {
                    await NotificationService.shared.requestPermission()
                }
        }
    }
}
