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
            .navigationTitle("Categories")
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
            statCard(title: "Categories", value: "\(categories.count)", icon: "square.grid.2x2.fill", color: .walletPrimary)
            statCard(title: "Total Budget", value: totalBudget.currencyFormatted(currency: currency), icon: "banknote.fill", color: .green)
            statCard(title: "Month Spent", value: totalSpent.currencyFormatted(currency: currency), icon: "arrow.up.circle.fill", color: .red)
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
            Text("Budget Overview")
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
            Text("All Categories")
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(categories) { cat in
                    CategoryCard(category: cat, currency: currency, onEdit: {
                        editingCategory = cat
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    })
                    .frame(maxHeight: .infinity)
                    .contextMenu {
                        Button("Edit") { editingCategory = cat }
                        if !cat.isDefault {
                            Button("Delete", role: .destructive) {
                                context.delete(cat)
                            }
                        }
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
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Text(category.totalSpent().currencyFormatted(currency: currency))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            if let budget = category.monthlyBudget, let progress = category.budgetProgress() {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(category.color.opacity(0.1)).frame(height: 4)
                        Capsule()
                            .fill(category.color)
                            .frame(width: geo.size.width * (appear ? progress : 0), height: 4)
                            .animation(.spring(response: 0.7), value: appear)
                    }
                }
                .frame(height: 4)

                Text("\(budget.currencyFormatted(currency: currency)) budget")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
