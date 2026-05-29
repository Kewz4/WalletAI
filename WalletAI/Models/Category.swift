import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var isDefault: Bool
    var monthlyBudget: Double?
    var transactions: [Transaction]

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        colorHex: String,
        isDefault: Bool = false,
        monthlyBudget: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.monthlyBudget = monthlyBudget
        self.transactions = []
    }

    var color: Color {
        Color(hex: colorHex) ?? .walletPrimary
    }

    func totalSpent(in month: Date = Date()) -> Double {
        let calendar = Calendar.current
        return transactions
            .filter { t in
                t.isExpense &&
                calendar.isDate(t.date, equalTo: month, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.amount }
    }

    func budgetProgress(in month: Date = Date()) -> Double? {
        guard let budget = monthlyBudget, budget > 0 else { return nil }
        return min(totalSpent(in: month) / budget, 1.0)
    }
}

extension Category {
    static let defaultCategories: [(name: String, icon: String, color: String)] = [
        ("Food & Drink",    "fork.knife",           "#FF6B6B"),
        ("Transport",       "car.fill",             "#4ECDC4"),
        ("Shopping",        "bag.fill",             "#45B7D1"),
        ("Entertainment",   "popcorn.fill",         "#96CEB4"),
        ("Health",          "heart.fill",           "#FF8B94"),
        ("Housing",         "house.fill",           "#A8E6CF"),
        ("Utilities",       "bolt.fill",            "#FFD93D"),
        ("Travel",          "airplane",             "#6C5CE7"),
        ("Education",       "book.fill",            "#00B894"),
        ("Income",          "arrow.down.circle.fill","#55EFC4"),
        ("Savings",         "banknote.fill",        "#FDCB6E"),
        ("Other",           "ellipsis.circle.fill", "#B2BEC3"),
    ]
}
