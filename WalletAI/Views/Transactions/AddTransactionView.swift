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
            .navigationTitle(isEditing ? L("tx.editTx") : (isExpense ? L("tx.addExpense") : L("tx.addIncome")))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
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
            }
            .task(id: "\(title)\(amount)") { validate() }
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
            try? context.save()
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
                Button(L("tx.expenses")) {
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

                Button(L("tx.income")) {
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
        AmountTextField(amount: $amount, currency: currency, textColor: .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isExpense ? Color.red.opacity(0.85) : Color.green.opacity(0.85),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
    }

    private var detailsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "pencil")
                    .frame(width: 24)
                    .foregroundStyle(Color.walletPrimary)
                TextField(L("tx.title_field"), text: $title)
                    .font(.body)
                    .submitLabel(.next)
            }
            .padding(16)
        }
        .glassCard()
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "tag.fill")
                    .frame(width: 24)
                    .foregroundStyle(Color.walletPrimary)
                Text(L("tx.category"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
                if let cat = selectedCategory {
                    Text(cat.iconName)
                        .font(.body)
                    Text(cat.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(cat.color)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                ForEach(categories) { cat in
                    let isSelected = selectedCategory?.id == cat.id
                    Button {
                        withAnimation(.springy) { selectedCategory = cat }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? cat.color : cat.color.opacity(0.12))
                                    .frame(width: 46, height: 46)
                                if isSelected {
                                    Circle()
                                        .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                                        .frame(width: 46, height: 46)
                                }
                                if cat.iconName.contains(".") {
                                    Image(systemName: cat.iconName)
                                        .font(.system(size: 18))
                                        .foregroundStyle(isSelected ? .white : cat.color)
                                } else {
                                    Text(cat.iconName)
                                        .font(.system(size: 20))
                                }
                            }
                            Text(cat.name)
                                .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? cat.color : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.springy, value: isSelected)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .glassCard()
    }

    private var dateSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "calendar")
                    .frame(width: 24)
                    .foregroundStyle(Color.walletPrimary)
                DatePicker(L("tx.date"), selection: $date, displayedComponents: [.date, .hourAndMinute])
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
                Toggle(L("tx.recurring"), isOn: $isRecurring.animation(.springy))
                    .tint(.orange)
            }
            .padding(16)

            if isRecurring {
                Divider().padding(.horizontal)
                HStack {
                    Image(systemName: "clock.fill")
                        .frame(width: 24)
                        .foregroundStyle(.orange)
                    Picker(L("tx.interval"), selection: $recurringInterval) {
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
            TextField(L("tx.notes"), text: $notes, axis: .vertical)
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
                Text(isExpense ? L("tx.saveExpense") : L("tx.saveIncome"))
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
