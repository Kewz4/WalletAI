import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]
    @Query private var budgets: [Budget]

    @State private var title: String = ""
    @State private var amount: Double = 0
    @State private var isExpense: Bool = true
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var isRecurring: Bool = false
    @State private var recurringInterval: Transaction.RecurringInterval = .monthly
    @State private var source: Transaction.Source = .manual
    @State private var showCategoryPicker = false
    @State private var showDatePicker = false
    @State private var isValid: Bool = false

    var prefilledTitle: String?
    var prefilledAmount: Double?
    var prefilledSource: Transaction.Source?
    var editingTransaction: Transaction?

    private var isEditing: Bool { editingTransaction != nil }
    private var currency: String { budgets.first?.currency ?? "USD" }

    init(title: String? = nil, amount: Double? = nil, source: Transaction.Source? = nil) {
        prefilledTitle = title
        prefilledAmount = amount
        prefilledSource = source
    }

    init(editing transaction: Transaction) {
        editingTransaction = transaction
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    typeToggle
                    amountSection
                    detailsSection
                    categorySection
                    dateSection
                    recurringSection
                    notesSection
                    saveButton
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Transaction" : (isExpense ? "Add Expense" : "Add Income"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if let tx = editingTransaction {
                    title = tx.title
                    amount = tx.amount
                    isExpense = tx.isExpense
                    date = tx.date
                    notes = tx.notes
                    selectedCategory = tx.category
                    source = tx.source
                    isRecurring = tx.isRecurring
                    recurringInterval = tx.recurringInterval ?? .monthly
                } else {
                    if let t = prefilledTitle  { title = t }
                    if let a = prefilledAmount { amount = a }
                    if let s = prefilledSource { source = s }
                    selectedCategory = categories.first { $0.name == "Other" }
                }
                validate()
            }
            .onChange(of: amount) { _, _ in validate() }
            .onChange(of: title)  { _, _ in validate() }
        }
    }

    private func validate() {
        isValid = amount > 0 && !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        if let tx = editingTransaction {
            tx.title = title
            tx.amount = amount
            tx.isExpense = isExpense
            tx.date = date
            tx.notes = notes
            tx.category = selectedCategory
            tx.source = source
            tx.isRecurring = isRecurring
            tx.recurringInterval = isRecurring ? recurringInterval : nil
        } else {
            let tx = Transaction(
                title: title,
                amount: amount,
                date: date,
                notes: notes,
                isExpense: isExpense,
                category: selectedCategory,
                source: source,
                isRecurring: isRecurring,
                recurringInterval: isRecurring ? recurringInterval : nil,
                currency: currency
            )
            context.insert(tx)
            LiveActivityService.shared.startActivity(for: tx)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        Task { await NotificationService.shared.checkBudgetAlerts(for: Array(categories)) }
        dismiss()
    }

    // MARK: - Subviews

    private var typeToggle: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                Button("Expense") {
                    withAnimation(.springy) { isExpense = true }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassEffect(
                    isExpense ? .regular.tint(Color.red).interactive() : .regular.interactive(),
                    in: .capsule
                )
                .foregroundStyle(isExpense ? Color.white : Color.secondary)

                Button("Income") {
                    withAnimation(.springy) { isExpense = false }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .glassEffect(
                    !isExpense ? .regular.tint(Color.green).interactive() : .regular.interactive(),
                    in: .capsule
                )
                .foregroundStyle(!isExpense ? Color.white : Color.secondary)
            }
            .padding(4)
        }
    }

    private var amountSection: some View {
        VStack(spacing: 8) {
            AmountTextField(amount: $amount, currency: currency)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .glassEffect(
                    .regular.tint(isExpense ? Color.red : Color.green),
                    in: .rect(cornerRadius: 20)
                )
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "pencil")
                    .frame(width: 24)
                    .foregroundStyle(Color.walletPrimary)
                TextField("Title", text: $title)
                    .font(.body)
                    .submitLabel(.next)
            }
            .padding(16)

            Divider().padding(.horizontal)

            HStack {
                Image(systemName: "tag.fill")
                    .frame(width: 24)
                    .foregroundStyle(Color.walletPrimary)
                Button {
                    showCategoryPicker = true
                } label: {
                    HStack {
                        Text(selectedCategory?.name ?? "Select Category")
                            .foregroundStyle(selectedCategory == nil ? Color.secondary : Color.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .glassCard()
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerView(selected: $selectedCategory, isExpense: isExpense)
        }
    }

    private var categorySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories.filter { _ in true }) { cat in
                    Button {
                        withAnimation(.springy) { selectedCategory = cat }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(cat.color.opacity(selectedCategory?.id == cat.id ? 0.3 : 0.1))
                                    .frame(width: 44, height: 44)
                                Text(cat.iconName)
                                    .font(.system(size: 20))
                            }
                            Text(cat.name)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .glassEffect(
                            selectedCategory?.id == cat.id
                                ? .regular.tint(cat.color).interactive()
                                : .regular.interactive(),
                            in: .rect(cornerRadius: 14)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollClipDisabled()
    }

    private var dateSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "calendar")
                    .frame(width: 24)
                    .foregroundStyle(Color.walletPrimary)
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .tint(Color.walletPrimary)
            }
            .padding(16)
        }
        .glassCard()
    }

    private var recurringSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .frame(width: 24)
                    .foregroundStyle(.orange)
                Toggle("Recurring", isOn: $isRecurring.animation(.springy))
                    .tint(.orange)
            }
            .padding(16)

            if isRecurring {
                Divider().padding(.horizontal)
                HStack {
                    Image(systemName: "clock.fill")
                        .frame(width: 24)
                        .foregroundStyle(.orange)
                    Picker("Interval", selection: $recurringInterval) {
                        ForEach(Transaction.RecurringInterval.allCases, id: \.self) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    .tint(.orange)
                }
                .padding(16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .glassCard()
    }

    private var notesSection: some View {
        HStack(alignment: .top) {
            Image(systemName: "note.text")
                .frame(width: 24)
                .foregroundStyle(Color.walletPrimary)
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
        .padding(16)
        .glassCard()
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text(isExpense ? "Save Expense" : "Save Income")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .glassEffect(
                .regular.tint(isExpense ? Color.red : Color.green).interactive(),
                in: .rect(cornerRadius: 16)
            )
            .foregroundStyle(.white)
            .opacity(isValid ? 1.0 : 0.4)
        }
        .disabled(!isValid)
        .buttonStyle(.plain)
    }
}
