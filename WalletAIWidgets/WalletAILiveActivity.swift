import ActivityKit
import WidgetKit
import SwiftUI

struct WalletAILiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalletTransactionAttributes.self) { context in
            // Lock screen / banner UI
            HStack(spacing: 14) {
                Text(context.state.categoryEmoji)
                    .font(.system(size: 36))
                    .padding(10)
                    .background(
                        Circle()
                            .fill(context.state.isExpense ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.state.categoryName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(context.state.formattedAmount)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(context.state.isExpense ? .red : .green)
            }
            .padding(16)
            .activityBackgroundTint(Color(.systemBackground).opacity(0.9))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.categoryEmoji)
                        .font(.system(size: 28))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.formattedAmount)
                        .font(.callout.bold().monospacedDigit())
                        .foregroundStyle(context.state.isExpense ? .red : .green)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.title)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Spacer()
                        Text(context.state.categoryName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Text(context.state.categoryEmoji)
                    .font(.body)
            } compactTrailing: {
                Text(context.state.formattedAmount)
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(context.state.isExpense ? .red : .green)
            } minimal: {
                Text(context.state.categoryEmoji)
                    .font(.caption)
            }
        }
    }
}
