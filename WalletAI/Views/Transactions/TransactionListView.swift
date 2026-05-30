import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var searchText = ""
    @State private var showAddTransaction = false
    @State private var filterCategory: Category? = nil
    @State private var filterType: FilterType = .all
    @State private var showVoiceInput = false

    @State private var speechService = SpeechRecognitionService()
    @State private var editingTransaction: Transaction? = nil

    enum FilterType: String, CaseIterable {
        case all = "All"
        case expenses = "Expenses"
        case income = "Income"
    }

    private var filtered: [Transaction] {
        transactions.filter { t in
            (searchText.isEmpty || t.title.localizedCaseInsensitiveContains(searchText) ||
             (t.merchantName?.localizedCaseInsensitiveContains(searchText) ?? false)) &&
            (filterCategory == nil || t.category?.id == filterCategory?.id) &&
            (filterType == .all || (filterType == .expenses ? t.isExpense : !t.isExpense))
        }
    }

    private var grouped: [(key: String, transactions: [Transaction])] {
        let byDate = Dictionary(grouping: filtered) { t -> String in
            if Calendar.current.isDateInToday(t.date)     { return "Today" }
            if Calendar.current.isDateInYesterday(t.date) { return "Yesterday" }
            return t.date.formatted(.dateTime.month(.wide).day().year())
        }
        let pinnedOrder = ["Today", "Yesterday"]
        let sorted = byDate.sorted { lhs, rhs in
            let li = pinnedOrder.firstIndex(of: lhs.key) ?? Int.max
            let ri = pinnedOrder.firstIndex(of: rhs.key) ?? Int.max
            if li != ri { return li < ri }
            return lhs.key > rhs.key
        }
        return sorted.map { (key: $0.key, transactions: $0.value) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    filterBar

                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.key) { group in
                            sectionView(title: group.key, transactions: group.transactions)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .searchable(text: $searchText, prompt: "Search transactions")
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showVoiceInput = true
                        } label: {
                            Image(systemName: "mic.fill")
                                .foregroundStyle(Color.walletPrimary)
                        }
                        Button {
                            showAddTransaction = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.walletPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .sheet(isPresented: $showVoiceInput) {
                VoiceTransactionSheet()
            }
            .sheet(item: $editingTransaction) { tx in
                AddTransactionView(editing: tx)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    filterButton(.all)
                    filterButton(.expenses)
                    filterButton(.income)
                }
                .padding(4)
            }
        }
        .scrollClipDisabled()
    }

    private func filterButton(_ type: FilterType) -> some View {
        let isSelected = filterType == type
        return Button(type.rawValue) {
            withAnimation(.springy) { filterType = type }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .glassEffect(
            isSelected ? .regular.tint(Color.walletPrimary).interactive() : .regular.interactive(),
            in: .capsule
        )
        .foregroundStyle(isSelected ? Color.white : Color.secondary)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No transactions yet")
                .font(.headline)
            Text("Tap + or use voice to add your first transaction")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func sectionView(title: String, transactions: [Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                let total = transactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
                if total > 0 {
                    Text("-\(total.currencyFormatted())")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)

            // List is required for swipe actions; scrollDisabled lets the outer ScrollView drive.
            List {
                ForEach(transactions) { tx in
                    TransactionRowView(transaction: tx)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparatorTint(Color.secondary.opacity(0.2))
                        // Swipe RIGHT → Edit
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { editingTransaction = tx } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        // Swipe LEFT → Delete
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation { context.delete(tx) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .frame(minHeight: CGFloat(transactions.count) * 70)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
