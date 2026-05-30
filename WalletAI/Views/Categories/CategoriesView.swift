import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Query private var categories: [Category]
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]

    @State private var showAddCategory = false
    @State private var editingCategory: Category? = nil

    private var currency: String { budgets.first?.currency ?? "USD" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary strip
                    summaryStrip

                    // Budget bars
                    if !categories.filter({ $0.monthlyBudget != nil }).isEmpty {
                        budgetSection
                    }

                    // Category grid
                    categoryGrid
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle(L("cat.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.walletPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                CategoryFormView()
            }
            .sheet(item: $editingCategory) { cat in
                CategoryFormView(category: cat)
            }
        }
    }

    private var summaryStrip: some View {
        let totalBudget = categories.compactMap { $0.monthlyBudget }.reduce(0, +)
        let totalSpent = categories.reduce(0) { $0 + $1.totalSpent() }

        return HStack(spacing: 12) {
            statCard(title: L("tab.categories"), value: "\(categories.count)", icon: "square.grid.2x2.fill", color: .walletPrimary)
            statCard(title: L("cat.totalBudget"), value: totalBudget.currencyFormatted(currency: currency), icon: "banknote.fill", color: .green)
            statCard(title: L("cat.monthSpent"), value: totalSpent.currencyFormatted(currency: currency), icon: "arrow.up.circle.fill", color: .red)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(color.opacity(0.2), lineWidth: 1))
        )
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("cat.budgetOverview"))
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(categories.filter { $0.monthlyBudget != nil }) { cat in
                    if let progress = cat.budgetProgress() {
                        LinearBudgetBar(progress: progress, category: cat)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("cat.all"))
                .font(.headline)
                .padding(.horizontal, 4)

            Text(L("cat.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(categories) { cat in
                    NavigationLink(destination: CategoryTransactionsView(category: cat)) {
                        CategoryCard(category: cat, currency: currency, onEdit: {
                            editingCategory = cat
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        })
                        .frame(maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { editingCategory = cat } label: {
                            Label(L("common.edit"), systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            context.delete(cat)
                        } label: {
                            Label(L("common.delete"), systemImage: "trash")
                        }
                    } preview: {
                        CategoryCard(category: cat, currency: currency)
                            .frame(width: 180)
                            .padding(4)
                    }
                }
            }
        }
    }
}

struct CategoryCard: View {
    let category: Category
    let currency: String
    var onEdit: (() -> Void)? = nil

    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    if category.iconName.contains(".") {
                        Image(systemName: category.iconName)
                            .font(.system(size: 18))
                            .foregroundStyle(category.color)
                    } else {
                        Text(category.iconName)
                            .font(.system(size: 20))
                    }
                }
                Spacer()
                Button { onEdit?() } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(category.color.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            Text(category.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(category.totalSpent().currencyFormatted(currency: currency))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let budget = category.monthlyBudget, let progress = category.budgetProgress() {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(category.color.opacity(0.1)).frame(height: 3)
                        Capsule()
                            .fill(category.color)
                            .frame(width: geo.size.width * (appear ? progress : 0), height: 3)
                            .animation(.spring(response: 0.7), value: appear)
                    }
                }
                .frame(height: 3)

                Text("\(budget.currencyFormatted(currency: currency)) budget")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                // Placeholder to keep all cards the same height
                Color.clear.frame(height: 3)
                Text(" ").font(.caption2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(category.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(category.color.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear { appear = true }
    }
}

// MARK: - Category Transactions

struct CategoryTransactionsView: View {
    let category: Category
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var budgets: [Budget]
    @Environment(\.modelContext) private var context
    @State private var editingTransaction: Transaction? = nil

    private var currency: String { budgets.first?.currency ?? "USD" }

    private var transactions: [Transaction] {
        allTransactions.filter { $0.category?.id == category.id }
    }

    private var totalSpent: Double {
        transactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
    }
    private var totalIncome: Double {
        transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary bar
                HStack(spacing: 12) {
                    summaryTile(
                        label: L("tx.expenses"),
                        value: totalSpent.currencyFormatted(currency: currency),
                        color: .red
                    )
                    summaryTile(
                        label: L("tx.income"),
                        value: totalIncome.currencyFormatted(currency: currency),
                        color: .green
                    )
                    summaryTile(
                        label: L("common.transactions"),
                        value: "\(transactions.count)",
                        color: category.color
                    )
                }

                if transactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text(L("tx.empty"))
                            .font(.headline)
                    }
                    .padding(40)
                } else {
                    List {
                        ForEach(transactions) { tx in
                            TransactionRowView(transaction: tx)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparatorTint(Color.secondary.opacity(0.2))
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { editingTransaction = tx } label: {
                                        Label(L("tx.edit"), systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation { context.delete(tx) }
                                    } label: {
                                        Label(L("tx.delete"), systemImage: "trash")
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
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(Color.walletBackground.ignoresSafeArea())
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editingTransaction) { tx in
            AddTransactionView(editing: tx)
        }
    }

    private func summaryTile(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(color.opacity(0.18), lineWidth: 1))
        )
    }
}
