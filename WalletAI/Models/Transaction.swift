import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var title: String
    var amount: Double
    var date: Date
    var notes: String
    var isExpense: Bool
    var category: Category?
    var source: Source
    var merchantName: String?
    var receiptImageData: Data?
    var isRecurring: Bool
    var recurringInterval: RecurringInterval?
    var currency: String
    var tags: [String]

    enum Source: String, Codable {
        case manual, voice, applePay, receipt, ai
    }

    enum RecurringInterval: String, Codable, CaseIterable {
        case daily, weekly, biweekly, monthly, yearly

        var displayName: String {
            switch self {
            case .daily:     return "Daily"
            case .weekly:    return "Weekly"
            case .biweekly:  return "Every 2 Weeks"
            case .monthly:   return "Monthly"
            case .yearly:    return "Yearly"
            }
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        date: Date = Date(),
        notes: String = "",
        isExpense: Bool = true,
        category: Category? = nil,
        source: Source = .manual,
        merchantName: String? = nil,
        isRecurring: Bool = false,
        recurringInterval: RecurringInterval? = nil,
        currency: String = Locale.current.currency?.identifier ?? "USD",
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.date = date
        self.notes = notes
        self.isExpense = isExpense
        self.category = category
        self.source = source
        self.merchantName = merchantName
        self.isRecurring = isRecurring
        self.recurringInterval = recurringInterval
        self.currency = currency
        self.tags = tags
    }

    var formattedAmount: String {
        let sign = isExpense ? "-" : "+"
        return "\(sign)\(amount.currencyFormatted(currency: currency))"
    }
}
