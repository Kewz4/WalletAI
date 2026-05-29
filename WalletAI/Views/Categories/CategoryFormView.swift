import SwiftUI
import SwiftData

struct CategoryFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var category: Category? = nil

    @State private var name: String = ""
    @State private var selectedIcon: String = "📌"
    @State private var selectedColor: Color = .walletPrimary
    @State private var monthlyBudget: String = ""
    @State private var hasBudget: Bool = false

    let icons = [
        "🍕", "🍔", "🍜", "☕️", "🍺", "🛒",
        "🚗", "🚌", "✈️", "🚂", "⛽️", "🚴",
        "🛍️", "👗", "👟", "💄", "🎁", "🧴",
        "🎬", "🎮", "🎵", "📺", "🎭", "🎪",
        "🏥", "💊", "🏋️", "🧘", "🩺", "🦷",
        "🏠", "🏢", "🛋️", "🔧", "⚡️", "💧",
        "📚", "🎓", "✏️", "💻", "📱", "🔬",
        "💵", "💳", "🏦", "📈", "💰", "🪙",
        "🐾", "🌿", "⚽️", "🎨", "🗺️", "📌",
    ]

    let palette: [Color] = [
        Color(hex: "#FF6B6B")!, Color(hex: "#4ECDC4")!, Color(hex: "#45B7D1")!,
        Color(hex: "#96CEB4")!, Color(hex: "#FF8B94")!, Color(hex: "#A8E6CF")!,
        Color(hex: "#FFD93D")!, Color(hex: "#6C5CE7")!, Color(hex: "#00B894")!,
        Color(hex: "#55EFC4")!, Color(hex: "#FDCB6E")!, Color(hex: "#E17055")!,
        Color(hex: "#74B9FF")!, Color(hex: "#A29BFE")!, Color(hex: "#FD79A8")!,
        Color(hex: "#00CEC9")!
    ]

    private var isEditing: Bool { category != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview
                    previewCard

                    // Name
                    nameField

                    // Icon picker
                    iconPicker

                    // Color picker
                    colorPicker

                    // Budget
                    budgetSection

                    // Save
                    saveButton
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if let cat = category {
                    name = cat.name
                    selectedIcon = cat.iconName
                    selectedColor = cat.color
                    if let budget = cat.monthlyBudget {
                        hasBudget = true
                        monthlyBudget = String(format: "%.0f", budget)
                    }
                }
            }
        }
    }

    private var previewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(selectedColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                Text(selectedIcon)
                    .font(.system(size: 26))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "Category Name" : name)
                    .font(.headline)
                    .foregroundStyle(name.isEmpty ? Color.secondary : Color.primary)
                if hasBudget, let budget = Double(monthlyBudget), budget > 0 {
                    Text("\(budget.currencyFormatted()) / month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(20)
        .glassCard(tint: selectedColor)
        .animation(.springy, value: selectedColor)
        .animation(.springy, value: selectedIcon)
    }

    private var nameField: some View {
        HStack {
            Image(systemName: "pencil")
                .foregroundStyle(Color.walletPrimary)
            TextField("Category Name", text: $name)
                .font(.body)
        }
        .padding(16)
        .glassCard()
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        withAnimation(.springy) { selectedIcon = icon }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(icon)
                            .font(.system(size: 22))
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedIcon == icon ? selectedColor.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(selectedIcon == icon ? selectedColor : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                ForEach(palette, id: \.hex) { color in
                    Button {
                        withAnimation(.springy) { selectedColor = color }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 36, height: 36)
                            if selectedColor.hex == color.hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    private var budgetSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "banknote.fill")
                    .foregroundStyle(.green)
                Toggle("Monthly Budget", isOn: $hasBudget.animation(.springy))
                    .tint(.green)
            }
            .padding(16)

            if hasBudget {
                Divider().padding(.horizontal)
                HStack {
                    Image(systemName: "dollarsign.circle")
                        .foregroundStyle(.green)
                    TextField("Budget Amount", text: $monthlyBudget)
                        .keyboardType(.decimalPad)
                }
                .padding(16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .glassCard()
    }

    private var saveButton: some View {
        Button { save() } label: {
            HStack {
                Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                Text(isEditing ? "Update Category" : "Create Category")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .glassEffect(.regular.tint(Color.walletPrimary).interactive(), in: .rect(cornerRadius: 16))
            .foregroundStyle(Color.walletPrimary)
            .opacity(isValid ? 1.0 : 0.4)
        }
        .disabled(!isValid)
        .buttonStyle(.plain)
    }

    private func save() {
        if let cat = category {
            cat.name = name
            cat.iconName = selectedIcon
            cat.colorHex = selectedColor.hex
            cat.monthlyBudget = hasBudget ? Double(monthlyBudget) : nil
        } else {
            let cat = Category(
                name: name,
                iconName: selectedIcon,
                colorHex: selectedColor.hex,
                monthlyBudget: hasBudget ? Double(monthlyBudget) : nil
            )
            context.insert(cat)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

struct CategoryPickerView: View {
    @Binding var selected: Category?
    let isExpense: Bool
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(categories) { cat in
                        Button {
                            selected = cat
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(cat.color.opacity(selected?.id == cat.id ? 0.3 : 0.1))
                                        .frame(width: 48, height: 48)
                                    Text(cat.iconName)
                                        .font(.system(size: 22))
                                }
                                Text(cat.name)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(12)
                            .glassEffect(
                                selected?.id == cat.id
                                    ? .regular.tint(cat.color).interactive()
                                    : .regular.interactive(),
                                in: .rect(cornerRadius: 14)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
