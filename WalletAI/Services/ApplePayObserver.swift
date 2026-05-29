import Foundation
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

    // Shortcut automation instructions (shown in Settings)
    static let shortcutInstructions = """
    To enable Apple Pay auto-logging:
    1. Open the Shortcuts app
    2. Tap Automation → New Automation
    3. Choose "Apple Pay" as the trigger
    4. Add "Open URL" action with:
       walletai://applepay?amount=[Payment Amount]&merchant=[Merchant Name]
    5. Enable "Run Immediately"
    """

    static let shortcutURL = "shortcuts://create-shortcut"
}
