import ActivityKit
import Foundation

struct WalletTransactionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var amount: Double
        var categoryEmoji: String
        var categoryName: String
        var isExpense: Bool
        var formattedAmount: String
    }

    var transactionID: String
}
