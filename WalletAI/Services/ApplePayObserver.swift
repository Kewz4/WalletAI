import AppIntents
import Foundation
import SwiftData
import UserNotifications

// Apple Pay transaction interception is done via Shortcuts automation.
// This service handles the incoming Shortcut URL scheme trigger and
// parses the payment data to pre-fill a transaction.

@MainActor
@Observable
final class ApplePayObserver {
    var pendingTransaction: ParsedTransaction? = nil
    var showTransactionPrompt: Bool = false

    // Called when app receives a URL from the Shortcuts automation
    func handleShortcutURL(_ url: URL) {
        guard url.scheme == "walletai",
              url.host == "applepay",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }

        let params = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
            item.value.map { (item.name, $0) }
        })

        if let amountStr = params["amount"], let amount = Double(amountStr) {
            let merchant = params["merchant"] ?? "Apple Pay Purchase"
            pendingTransaction = ParsedTransaction(title: merchant, amount: amount, isExpense: true)
            showTransactionPrompt = true
        }
    }

    static let applePayURL = "walletai://applepay?amount=[Payment Amount]&merchant=[Merchant Name]"
}

// MARK: - Background App Intent (runs without opening the app)

struct LogApplePayTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Apple Pay Transaction"
    static var description = IntentDescription("Silently log an Apple Pay purchase to WalletAI — no app launch needed")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Amount", description: "Purchase amount")
    var amount: Double

    @Parameter(title: "Merchant", description: "Store or merchant name", default: "Apple Pay Purchase")
    var merchant: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let schema = Schema([Transaction.self, Category.self, Budget.self, AIConversation.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let allCategories = try context.fetch(FetchDescriptor<Category>())
        let category = allCategories.first { $0.name == "Shopping" }
            ?? allCategories.first { $0.name == "Other" }
            ?? allCategories.first

        let tx = Transaction(
            title: merchant,
            amount: amount,
            date: Date(),
            notes: "Auto-logged via Apple Pay",
            isExpense: true,
            category: category,
            source: .applePay
        )
        context.insert(tx)
        try context.save()

        // Notify the user without opening the app
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "💳 Apple Pay Logged"
        content.body = "\(merchant) — \(amount.currencyFormatted())"
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "applepay-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(req)

        return .result(dialog: "Logged \(merchant) — \(amount.currencyFormatted())")
    }
}
