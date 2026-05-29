import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()

    nonisolated(unsafe) private var currentActivity: Activity<WalletTransactionAttributes>?

    func startActivity(for transaction: Transaction) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any existing activity first
        endCurrentActivity()

        let state = WalletTransactionAttributes.ContentState(
            title: transaction.title,
            amount: transaction.amount,
            categoryEmoji: transaction.category?.iconName ?? "💰",
            categoryName: transaction.category?.name ?? "Other",
            isExpense: transaction.isExpense,
            formattedAmount: transaction.formattedAmount
        )

        let attributes = WalletTransactionAttributes(transactionID: transaction.id.uuidString)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(300))

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activities may not be available in all configurations
        }
    }

    nonisolated func endCurrentActivity() {
        let activity = currentActivity
        currentActivity = nil
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
        }
    }
}
