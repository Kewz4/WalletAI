import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let transaction: Transaction

    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Amount header
                    amountHeader

                    // Details card
                    detailsCard

                    // Notes
                    if !transaction.notes.isEmpty {
                        notesCard
                    }

                    // Actions
                    actions
                }
                .padding(16)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEdit = true } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.walletPrimary)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showEdit) {
                AddTransactionView(editing: transaction)
            }
            .confirmationDialog("Delete Transaction?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    context.delete(transaction)
                    dismiss()
                }
            }
        }
    }

    private var amountHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(transaction.category?.color.opacity(0.2) ?? Color.secondary.opacity(0.1))
                    .frame(width: 72, height: 72)
                Text(transaction.category?.iconName ?? "💰")
                    .font(.system(size: 32))
            }

            Text(transaction.formattedAmount)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(transaction.isExpense ? Color.primary : Color.green)

            if let cat = transaction.category {
                Text(cat.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(icon: "text.quote", label: "Title", value: transaction.title)
            Divider().padding(.horizontal)
            detailRow(icon: "calendar", label: "Date", value: transaction.date.formatted(.dateTime.month().day().year().hour().minute()))
            Divider().padding(.horizontal)
            detailRow(icon: "cpu", label: "Source", value: transaction.source.rawValue.capitalized)
            if transaction.isRecurring, let interval = transaction.recurringInterval {
                Divider().padding(.horizontal)
                detailRow(icon: "arrow.clockwise", label: "Recurring", value: interval.displayName)
            }
        }
        .glassCard()
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.walletPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
            }
            Spacer()
        }
        .padding(16)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(transaction.notes)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    private var actions: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Delete Transaction", systemImage: "trash.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(16)
                .glassEffect(.regular.tint(.red).interactive(), in: .rect(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
