import Foundation
import SwiftData

enum SeedData {
    // Maps old SF symbol iconNames → emoji for migration
    private static let iconMigration: [String: String] = [
        "fork.knife": "🍕", "car.fill": "🚗", "bag.fill": "🛍️",
        "popcorn.fill": "🎬", "heart.fill": "🏥", "house.fill": "🏠",
        "bolt.fill": "⚡️", "airplane": "✈️", "book.fill": "📚",
        "arrow.down.circle.fill": "💵", "banknote.fill": "🏦",
        "ellipsis.circle.fill": "📌"
    ]

    @MainActor
    static func seedIfNeeded(container: ModelContainer) {
        let context = container.mainContext

        // Migrate existing categories from SF symbol names to emojis
        if let existing = try? context.fetch(FetchDescriptor<Category>()) {
            for cat in existing {
                if let emoji = iconMigration[cat.iconName] {
                    cat.iconName = emoji
                }
            }
            try? context.save()
        }

        let descriptor = FetchDescriptor<Category>()
        guard (try? context.fetchCount(descriptor)) == 0 else { return }

        for (name, icon, color) in Category.defaultCategories {
            let cat = Category(name: name, iconName: icon, colorHex: color, isDefault: true)
            if name == "Food & Drink"  { cat.monthlyBudget = 400 }
            if name == "Transport"     { cat.monthlyBudget = 200 }
            if name == "Entertainment" { cat.monthlyBudget = 150 }
            context.insert(cat)
        }

        let budget = Budget(totalMonthlyLimit: 2500)
        context.insert(budget)

        try? context.save()
    }
}
