import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var categories: [Category]

    @State private var showAddTransaction = false
    @State private var selectedPeriod: Period = .month
    @Namespace private var glassNS

    enum Period: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
    }

    private var currentBudget: Budget? { budgets.first }
    private var currency: String { currentBudget?.currency ?? "USD" }

    private var filteredTransactions: [Transaction] {
        let now = Date()
        return transactions.filter { t in
            switch selectedPeriod {
            case .week:  return t.date >= now.daysAgo(7)
            case .month: return t.date >= now.startOfMonth
            case .year:  return Calendar.current.isDate(t.date, equalTo: now, toGranularity: .year)
            }
        }
    }

    private var totalSpent: Double {
        filteredTransactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    private var totalIncome: Double {
        filteredTransactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    private var budgetProgress: Double {
        guard let b = currentBudget, b.totalMonthlyLimit > 0 else { return 0 }
        return totalSpent / b.totalMonthlyLimit
    }

    private var dailyChartData: [(label: String, amount: Double)] {
        let calendar = Calendar.current
        let days = 7
        return (0..<days).reversed().map { i in
            let date = Date().daysAgo(i)
            let label = i == 0 ? "Today" : date.formatted(.dateTime.weekday(.abbreviated))
            let total = transactions
                .filter { calendar.isDate($0.date, inSameDayAs: date) && $0.isExpense }
                .reduce(0) { $0 + $1.amount }
            return (label, total)
        }
    }

    private var categoryBreakdown: [(category: String, amount: Double, color: Color)] {
        let expenses = filteredTransactions.filter { $0.isExpense }
        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Other" }
        let totals: [(String, Double)] = grouped.map { ($0.key, $0.value.reduce(0.0) { $0 + $1.amount }) }
        return totals
            .sorted { $0.1 > $1.1 }
            .prefix(6)
            .compactMap { key, val in
                let color: Color = categories.first { $0.name == key }?.color ?? Color.secondary
                return (key, val, color)
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header balance card
                    balanceCard

                    // Period selector
                    periodSelector

                    // Budget ring + stats
                    if let budget = currentBudget, selectedPeriod == .month {
                        budgetSection(budget: budget)
                    }

                    // Spending chart
                    chartSection

                    // Category breakdown
                    if !categoryBreakdown.isEmpty {
                        categorySection
                    }

                    // Recent transactions
                    recentSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle("WalletAI")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddTransaction = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.walletPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
        }
    }

    // MARK: - Subviews

    private var balanceCard: some View {
        VStack(spacing: 12) {
            Text("Net Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text((totalIncome - totalSpent).currencyFormatted(currency: currency))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.springy, value: totalIncome - totalSpent)

            HStack(spacing: 24) {
                statBadge(label: "In", amount: totalIncome, color: .green, icon: "arrow.down.circle.fill")
                statBadge(label: "Out", amount: totalSpent, color: .red, icon: "arrow.up.circle.fill")
            }
        }
        .padding(24)
        .glassEffect(.regular.tint(Color.walletPrimary).interactive(), in: .rect(cornerRadius: 24))
        .frame(maxWidth: .infinity)
    }

    private func statBadge(label: String, amount: Double, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(amount.currencyFormatted(currency: currency))
                    .font(.subheadline.bold())
                    .contentTransition(.numericText())
            }
        }
    }

    private var periodSelector: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                periodButton(.week)
                periodButton(.month)
                periodButton(.year)
            }
            .padding(4)
        }
    }

    private func periodButton(_ period: Period) -> some View {
        let isSelected = selectedPeriod == period
        return Button(period.rawValue) {
            withAnimation(.springy) { selectedPeriod = period }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(
            isSelected ? .regular.tint(Color.walletPrimary).interactive() : .regular.interactive(),
            in: .capsule
        )
        .foregroundStyle(isSelected ? Color.walletPrimary : Color.secondary)
    }

    private func budgetSection(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Budget")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 20) {
                BudgetProgressRing(
                    progress: budgetProgress,
                    spent: totalSpent,
                    total: budget.totalMonthlyLimit,
                    currency: currency,
                    size: 140
                )

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categories.filter { $0.monthlyBudget != nil }.prefix(3), id: \.id) { cat in
                        if let prog = cat.budgetProgress() {
                            LinearBudgetBar(progress: prog, category: cat)
                        }
                    }
                }
            }
            .padding(20)
            .glassCard()
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 Days")
                .font(.headline)
                .padding(.horizontal, 4)

            SpendingBarChart(data: dailyChartData, currency: currency)
                .padding(16)
                .glassCard()
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(categoryBreakdown.prefix(4), id: \.category) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text(item.category)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        Text(item.amount.currencyFormatted(currency: currency))
                            .font(.subheadline.bold())
                        Text((item.amount / max(totalSpent, 1)).percentageFormatted())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 16, tint: item.color)
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    TransactionListView()
                }
                .font(.subheadline)
                .foregroundStyle(Color.walletPrimary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                let recentTx = filteredTransactions.sorted(by: { $0.date > $1.date }).prefix(5)
                ForEach(Array(recentTx)) { tx in
                    TransactionRowView(transaction: tx)
                    if tx.id != recentTx.last?.id {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .glassCard()
        }
    }
}
