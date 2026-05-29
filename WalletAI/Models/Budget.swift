import Foundation
import SwiftData

@Model
final class Budget {
    var id: UUID
    var totalMonthlyLimit: Double
    var month: Date
    var currency: String
    var alerts: [BudgetAlert]

    struct BudgetAlert: Codable {
        var threshold: Double
        var isEnabled: Bool

        static let defaults = [
            BudgetAlert(threshold: 0.75, isEnabled: true),
            BudgetAlert(threshold: 0.9, isEnabled: true),
            BudgetAlert(threshold: 1.0, isEnabled: true),
        ]
    }

    init(
        id: UUID = UUID(),
        totalMonthlyLimit: Double = 2000,
        month: Date = Date(),
        currency: String = Locale.current.currency?.identifier ?? "USD",
        alerts: [BudgetAlert] = BudgetAlert.defaults
    ) {
        self.id = id
        self.totalMonthlyLimit = totalMonthlyLimit
        self.month = month
        self.currency = currency
        self.alerts = alerts
    }
}
