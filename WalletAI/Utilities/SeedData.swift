import Foundation
import SwiftData

enum SeedData {
    @MainActor
    static func seedIfNeeded(container: ModelContainer) {
        let context = container.mainContext
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
