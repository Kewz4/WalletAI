import Foundation
import UserNotifications
import SwiftUI

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func checkBudgetAlerts(for categories: [Category]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        for category in categories {
            guard let budget = category.monthlyBudget, budget > 0 else { continue }
            let spent = category.totalSpent()
            let progress = spent / budget

            let threshold: Double
            let message: String
            let identifier: String

            if progress >= 1.0 {
                threshold = 1.0
                message = "You've exceeded your \(category.name) budget of \(budget.currencyFormatted())!"
                identifier = "budget-over-\(category.id)"
            } else if progress >= 0.9 {
                threshold = 0.9
                message = "90% of your \(category.name) budget used. \((budget - spent).currencyFormatted()) remaining."
                identifier = "budget-90-\(category.id)"
            } else if progress >= 0.75 {
                threshold = 0.75
                message = "75% of your \(category.name) budget used."
                identifier = "budget-75-\(category.id)"
            } else {
                continue
            }

            // Avoid duplicate notifications for same threshold
            let pending = await center.pendingNotificationRequests()
            if pending.contains(where: { $0.identifier == identifier }) { continue }
            let delivered = await center.deliveredNotifications()
            if delivered.contains(where: { $0.request.identifier == identifier }) { continue }

            let content = UNMutableNotificationContent()
            content.title = "💰 Budget Alert — \(category.name)"
            content.body = message
            content.sound = .default
            content.categoryIdentifier = "BUDGET_ALERT"

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func scheduleTransactionRegistered(title: String, amount: Double, categoryEmoji: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(categoryEmoji) Transaction Logged"
        content.body = "\(title) — \(amount.currencyFormatted())"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "tx-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
}
