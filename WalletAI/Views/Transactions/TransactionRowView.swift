import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 14) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(transaction.category?.color.opacity(0.15) ?? Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Text(transaction.category?.iconName ?? "💰")
                        .font(.system(size: 20))
                }

                // Title + date
                VStack(alignment: .leading, spacing: 3) {
                    Text(transaction.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(transaction.date.formatted(.dateTime.month().day().hour().minute()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if transaction.source == .voice {
                            Image(systemName: "mic.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.walletPrimary.opacity(0.7))
                        } else if transaction.source == .applePay {
                            Image(systemName: "apple.logo")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if transaction.isRecurring {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange.opacity(0.8))
                        }
                    }
                }

                Spacer()

                // Amount
                Text(transaction.formattedAmount)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(transaction.isExpense ? Color.primary : Color.green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            TransactionDetailView(transaction: transaction)
        }
    }
}
