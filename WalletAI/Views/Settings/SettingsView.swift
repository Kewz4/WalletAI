import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var budgets: [Budget]
    @Query private var transactions: [Transaction]

    @AppStorage(Constants.Storage.preferredCurrencyKey)  private var preferredCurrency     = "USD"
    @AppStorage(Constants.Storage.notificationsEnabledKey) private var notificationsEnabled = true
    @AppStorage(Constants.Storage.biometricEnabledKey)   private var biometricEnabled       = false
    @AppStorage(Constants.Storage.themeKey)              private var themeKey               = "default"
    @AppStorage(Constants.Storage.colorSchemeKey)        private var colorSchemeRaw         = "system"

    @State private var deepSeekService = DeepSeekService()
    @State private var showAPIKey = false
    @State private var showBudgetEdit = false
    @State private var showExport = false
    @State private var showDeleteConfirm = false
    @State private var budgetAmount: Double = 2500
    @State private var showApplePayInfo = false

    private var currentBudget: Budget? { budgets.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile header
                    profileHeader

                    // Budget settings
                    budgetSection

                    // AI settings
                    aiSection

                    // Automation
                    automationSection

                    // Appearance
                    appearanceSection

                    // Preferences
                    preferencesSection

                    // Data
                    dataSection

                    // About
                    aboutSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Sections

    private var profileHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.walletPrimary.opacity(0.8), .walletAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("WalletAI")
                    .font(.title3.bold())
                Text("\(transactions.count) transactions tracked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .glassCard()
    }

    private var budgetSection: some View {
        settingsSection(title: "Budget", icon: "banknote.fill", color: .green) {
            settingsRow(icon: "chart.line.uptrend.xyaxis", title: "Monthly Limit") {
                Button {
                    budgetAmount = currentBudget?.totalMonthlyLimit ?? 2500
                    showBudgetEdit = true
                } label: {
                    Text(currentBudget?.totalMonthlyLimit.currencyFormatted(currency: preferredCurrency) ?? "Set limit")
                        .foregroundStyle(Color.walletPrimary)
                }
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "globe", title: "Currency") {
                Picker("Currency", selection: $preferredCurrency) {
                    ForEach(supportedCurrencies, id: \.self) { c in
                        Text(c).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.walletPrimary)
            }
        }
        .sheet(isPresented: $showBudgetEdit) {
            BudgetEditSheet(budget: currentBudget, initialAmount: budgetAmount)
        }
    }

    private var aiSection: some View {
        settingsSection(title: "AI Assistant", icon: "sparkles", color: .walletPrimary) {
            settingsRow(icon: "key.fill", title: "DeepSeek API Key") {
                Button {
                    showAPIKey = true
                } label: {
                    Text(deepSeekService.hasAPIKey ? "Configured ✓" : "Add Key")
                        .foregroundStyle(deepSeekService.hasAPIKey ? Color.green : Color.walletPrimary)
                }
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "cpu", title: "Model") {
                Text("deepseek-chat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showAPIKey) {
            APIKeySetupView(service: deepSeekService)
        }
    }

    private var automationSection: some View {
        settingsSection(title: "Automation", icon: "bolt.fill", color: .orange) {
            settingsRow(icon: "apple.logo", title: "Apple Pay Auto-Log") {
                Button {
                    showApplePayInfo = true
                } label: {
                    Text("Setup →")
                        .foregroundStyle(.orange)
                }
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "mic.fill", title: "Voice Recognition") {
                Text("Always On")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showApplePayInfo) {
            ApplePaySetupView()
        }
    }

    private var appearanceSection: some View {
        settingsSection(title: "Appearance", icon: "paintbrush.fill", color: Color(hex: "#A855F7")!) {
            // Theme picker
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "swatchpalette.fill")
                        .frame(width: 24)
                        .foregroundStyle(Color.walletPrimary)
                    Text("Theme")
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            themeKey = theme.rawValue
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(theme.primaryColor)
                                        .frame(width: 36, height: 36)
                                    if themeKey == theme.rawValue {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 2)
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "checkmark")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                Text("\(theme.emoji) \(theme.displayName)")
                                    .font(.caption2)
                                    .foregroundStyle(themeKey == theme.rawValue ? Color.walletPrimary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .animation(.springy, value: themeKey)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Divider().padding(.horizontal)

            // Color scheme
            settingsRow(icon: "circle.lefthalf.filled", title: "Appearance") {
                Picker("", selection: $colorSchemeRaw) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.menu)
                .tint(Color.walletPrimary)
            }
        }
    }

    private var preferencesSection: some View {
        settingsSection(title: "Preferences", icon: "gearshape.fill", color: .secondary) {
            settingsRow(icon: "bell.fill", title: "Budget Alerts") {
                Toggle("", isOn: $notificationsEnabled)
                    .tint(Color.walletPrimary)
                    .labelsHidden()
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "faceid", title: "Face ID Lock") {
                Toggle("", isOn: $biometricEnabled)
                    .tint(Color.walletPrimary)
                    .labelsHidden()
            }
        }
    }

    private var dataSection: some View {
        settingsSection(title: "Data", icon: "externaldrive.fill", color: .blue) {
            settingsRow(icon: "square.and.arrow.up", title: "Export CSV") {
                Button {
                    exportCSV()
                } label: {
                    Text("Export")
                        .foregroundStyle(.blue)
                }
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "trash.fill", title: "Delete All Data") {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text("Delete")
                        .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog("Delete all data?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { deleteAll() }
        }
    }

    private var aboutSection: some View {
        VStack(spacing: 10) {
            Text("💼")
                .font(.system(size: 40))
            Text("WalletAI")
                .font(.headline)
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
                .padding(.horizontal, 40)
                .padding(.vertical, 4)
            Text("Dedicated to my Lord and Savior Jesus Christ,\nand my precious Cami ❤️")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Romans 8:28")
                .font(.caption2.italic())
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .glassCard()
        }
    }

    private func settingsRow<Trailing: View>(icon: String, title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.walletPrimary)
            Text(title)
                .font(.body)
            Spacer()
            trailing()
        }
        .padding(16)
    }

    private func exportCSV() {
        let header = "Date,Title,Amount,Category,Type,Notes\n"
        let rows = transactions.map { t in
            "\(t.date.formatted()),\"\(t.title)\",\(t.amount),\"\(t.category?.name ?? "Other")\",\(t.isExpense ? "Expense" : "Income"),\"\(t.notes)\""
        }.joined(separator: "\n")
        let csv = header + rows
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WalletAI_Export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        // Share via UIActivityViewController would be triggered via a ShareLink in production
    }

    private func deleteAll() {
        try? context.delete(model: Transaction.self)
        try? context.delete(model: Category.self)
        try? context.delete(model: Budget.self)
        SeedData.seedIfNeeded(container: context.container)
    }
}

struct BudgetEditSheet: View {
    let budget: Budget?
    let initialAmount: Double
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Monthly Budget Limit")
                        .font(.headline)
                    AmountTextField(amount: $amount, currency: "USD")
                        .padding(20)
                        .glassCard()
                }

                Button("Save") {
                    if let b = budget {
                        b.totalMonthlyLimit = amount
                    } else {
                        let b = Budget(totalMonthlyLimit: amount)
                        context.insert(b)
                    }
                    dismiss()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(16)
                .glassEffect(.regular.tint(Color.walletPrimary).interactive(), in: .rect(cornerRadius: 16))
                .foregroundStyle(Color.walletPrimary)
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle("Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { amount = initialAmount }
        }
    }
}

struct ApplePaySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlCopied = false

    private let urlScheme = ApplePayObserver.applePayURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack(spacing: 16) {
                        Text("💳")
                            .font(.system(size: 48))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Pay Auto-Logging")
                                .font(.title3.bold())
                            Text("Log purchases without opening the app")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(20)
                    .glassCard()

                    // Recommended: App Intent
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recommended — Runs in Background")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.walletPrimary)
                            Spacer()
                            Text("✨ No app launch")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.walletPrimary.opacity(0.1))
                                .foregroundStyle(Color.walletPrimary)
                                .clipShape(Capsule())
                        }

                        Text("Works even when your phone is locked. The transaction saves silently and a notification confirms it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            stepRow(number: "1", text: "Open the **Shortcuts** app")
                            stepRow(number: "2", text: "Tap **Automation** → **New Automation**")
                            stepRow(number: "3", text: "Select **Apple Pay** as the trigger")
                            stepRow(number: "4", text: "Tap **New Blank Automation** (not Quick Action)")
                            stepRow(number: "5", text: "Search for **Log Apple Pay Transaction** (WalletAI)")
                            stepRow(number: "6", text: "Set **Amount** to `Payment Amount` variable, **Merchant** to `Merchant Name`")
                            stepRow(number: "7", text: "Turn off **Ask Before Running** — tap **Don't Ask**")
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(16)
                    .glassCard()

                    // Fallback: URL Scheme
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fallback — Opens the App")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("Use this if the App Intent doesn't appear in Shortcuts. The app will open and let you confirm the transaction.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            stepRow(number: "1", text: "Open **Shortcuts** → **Automation** → **New Automation**")
                            stepRow(number: "2", text: "Select **Apple Pay** as the trigger")
                            stepRow(number: "3", text: "Add an **Open URL** action")
                            stepRow(number: "4", text: "Paste the URL below, then set **Run Immediately**")
                        }
                        .padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                        // URL display + copy
                        HStack(spacing: 0) {
                            Text(urlScheme)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)

                            Button {
                                UIPasteboard.general.string = urlScheme
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.springy) { urlCopied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation(.springy) { urlCopied = false }
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: urlCopied ? "checkmark" : "doc.on.doc")
                                        .font(.body)
                                    Text(urlCopied ? "Copied!" : "Copy")
                                        .font(.caption2.bold())
                                }
                                .frame(width: 64)
                                .padding(.vertical, 12)
                                .background(urlCopied ? Color.green.opacity(0.15) : Color.walletPrimary.opacity(0.1))
                                .foregroundStyle(urlCopied ? .green : Color.walletPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(urlCopied ? Color.green.opacity(0.4) : Color.walletPrimary.opacity(0.2), lineWidth: 1)
                        )
                        .animation(.springy, value: urlCopied)
                    }
                    .padding(16)
                    .glassCard()
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle("Apple Pay Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Color.walletPrimary.opacity(0.15))
                .foregroundStyle(Color.walletPrimary)
                .clipShape(Circle())
            Text(LocalizedStringKey(text))
                .font(.subheadline)
        }
    }
}
