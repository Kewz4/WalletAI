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
        VStack(spacing: 0) {
            // Balance
            VStack(spacing: 6) {
                Text("Net Balance")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                Text((totalIncome - totalSpent).currencyFormatted(currency: currency))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .animation(.springy, value: totalIncome - totalSpent)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 24)

            // Stats
            HStack(spacing: 0) {
                statBadge(label: "Income", amount: totalIncome, icon: "arrow.down.circle.fill")
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 1, height: 48)
                statBadge(label: "Expenses", amount: totalSpent, icon: "arrow.up.circle.fill")
            }
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [Color.walletPrimary, Color.walletAccent.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, -16)
    }

    private func statBadge(label: String, amount: Double, icon: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text(amount.currencyFormatted(currency: currency))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
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
        .foregroundStyle(isSelected ? Color.white : Color.secondary)
    }

    private func budgetSection(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Monthly Budget")
                    .font(.headline)
                Spacer()
                let pct = Int(min(budgetProgress, 1.0) * 100)
                Text("\(pct)% used")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(budgetProgress > 0.9 ? .red : Color.walletPrimary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 16) {
                // Overall progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Total Spent")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(totalSpent.currencyFormatted(currency: currency))
                            .font(.subheadline.bold())
                        Text("/ \(budget.totalMonthlyLimit.currencyFormatted(currency: currency))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 10)
                            Capsule()
                                .fill(budgetProgress > 0.9 ? Color.red : Color.walletPrimary)
                                .frame(width: geo.size.width * min(budgetProgress, 1.0), height: 10)
                                .animation(.springy, value: budgetProgress)
                        }
                    }
                    .frame(height: 10)
                }

                // Per-category rows
                let catsWithBudget = categories.filter { $0.monthlyBudget != nil }
                if !catsWithBudget.isEmpty {
                    Divider()
                    VStack(spacing: 14) {
                        ForEach(catsWithBudget, id: \.id) { cat in
                            categoryBudgetRow(cat: cat)
                        }
                    }
                }
            }
            .padding(20)
            .glassCard()
        }
    }

    private func categoryBudgetRow(cat: Category) -> some View {
        let catSpent = filteredTransactions
            .filter { $0.category?.id == cat.id && $0.isExpense }
            .reduce(0.0) { $0 + $1.amount }
        let limit = cat.monthlyBudget ?? 1
        let prog = min(catSpent / limit, 1.0)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(cat.iconName).font(.body)
                Text(cat.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(catSpent.currencyFormatted(currency: currency))
                    .font(.caption.bold())
                    .foregroundStyle(catSpent > limit ? .red : .primary)
                Text("/ \(limit.currencyFormatted(currency: currency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12)).frame(height: 5)
                    Capsule()
                        .fill(catSpent > limit ? Color.red : cat.color)
                        .frame(width: geo.size.width * prog, height: 5)
                        .animation(.springy, value: prog)
                }
            }
            .frame(height: 5)
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
