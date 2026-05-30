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
    @AppStorage("walletai_language")                     private var appLanguage            = "en"
    @AppStorage(Constants.Storage.personalityKey)        private var personalityKey         = "chill"

    @Environment(\.dismiss) private var dismiss
    @State private var deepSeekService = DeepSeekService()
    @State private var authService = AuthService.shared
    @State private var categorizationService = CategorizationService()
    @State private var showAPIKey = false
    @State private var showBudgetEdit = false
    @State private var showExport = false
    @State private var showDeleteConfirm = false
    @State private var budgetAmount: Double = 2500
    @State private var showApplePayInfo = false
    @State private var profileNameInput: String = ""
    @State private var profileEmailInput: String = ""

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
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var profileHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ProfileImageView(image: authService.profileImage, size: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(authService.isSignedIn
                         ? (authService.userName.isEmpty ? L("settings.walletaiUser") : authService.userName)
                         : L("settings.setupProfileHint"))
                        .font(.title3.bold())
                    if authService.isSignedIn && !authService.userEmail.isEmpty {
                        Text(authService.userEmail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(transactions.count) \(L("settings.txTracked"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if authService.isSignedIn {
                    Button {
                        authService.signOut()
                        profileNameInput = ""
                        profileEmailInput = ""
                    } label: {
                        Text(L("common.edit"))
                            .font(.caption)
                            .foregroundStyle(Color.walletPrimary)
                    }
                }
            }

            if !authService.isSignedIn {
                VStack(spacing: 10) {
                    TextField(L("settings.yourName"), text: $profileNameInput)
                        .textContentType(.name)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    TextField(L("settings.yourEmail"), text: $profileEmailInput)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    Button {
                        authService.setProfile(name: profileNameInput, email: profileEmailInput)
                    } label: {
                        Text(L("settings.saveProfile"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(13)
                            .glassEffect(.regular.tint(Color.walletPrimary).interactive(), in: .rect(cornerRadius: 13))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(profileNameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(profileNameInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
            }
        }
        .padding(20)
        .glassCard()
        .keyboardDoneButton()
        .onAppear {
            profileNameInput = authService.userName
            profileEmailInput = authService.userEmail
        }
    }

    private var budgetSection: some View {
        settingsSection(title: L("settings.budget"), icon: "banknote.fill", color: .green) {
            settingsRow(icon: "chart.line.uptrend.xyaxis", title: L("settings.monthlyLimitRow")) {
                Button {
                    budgetAmount = currentBudget?.totalMonthlyLimit ?? 2500
                    showBudgetEdit = true
                } label: {
                    Text(currentBudget?.totalMonthlyLimit.currencyFormatted(currency: preferredCurrency) ?? L("settings.setLimit"))
                        .foregroundStyle(Color.walletPrimary)
                }
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "globe", title: L("settings.currency")) {
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
        settingsSection(title: L("settings.aiSection"), icon: "sparkles", color: .walletPrimary) {
            settingsRow(icon: "key.fill", title: L("settings.groqKey")) {
                Button {
                    showAPIKey = true
                } label: {
                    Text(deepSeekService.hasAPIKey ? L("settings.configured") : L("settings.addKey"))
                        .foregroundStyle(deepSeekService.hasAPIKey ? Color.green : Color.walletPrimary)
                }
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "cpu", title: L("settings.modelRow")) {
                Text("Llama 3.3 70B")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().padding(.horizontal)

            // Re-analyze all transactions
            reAnalyzeRow
        }
        .sheet(isPresented: $showAPIKey) {
            APIKeySetupView(service: deepSeekService)
        }
    }

    @Query private var categories: [Category]

    private var reAnalyzeRow: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .frame(width: 24)
                    .foregroundStyle(Color.walletPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("settings.reAnalyze"))
                        .font(.body)
                    if let msg = categorizationService.completionMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if !categorizationService.statusMessage.isEmpty {
                        Text(categorizationService.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L("settings.reAnalyzeHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if categorizationService.isRunning {
                    VStack(spacing: 4) {
                        ProgressView(value: categorizationService.progress)
                            .frame(width: 48)
                            .tint(Color.walletPrimary)
                        Text("\(Int(categorizationService.progress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        Task {
                            await categorizationService.analyzeAll(
                                transactions: transactions,
                                categories: categories,
                                context: context
                            )
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text(L("settings.analyze"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.walletPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(transactions.isEmpty)
                }
            }
            .padding(16)
            .animation(.springy, value: categorizationService.isRunning)
        }
    }

    private var automationSection: some View {
        settingsSection(title: L("settings.automation"), icon: "bolt.fill", color: .orange) {
            settingsRow(icon: "apple.logo", title: L("settings.applePay")) {
                Button {
                    showApplePayInfo = true
                } label: {
                    Text(L("settings.setup"))
                        .foregroundStyle(.orange)
                }
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "mic.fill", title: L("settings.voice")) {
                Text(L("settings.alwaysOn"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showApplePayInfo) {
            ApplePaySetupView()
        }
    }

    private var appearanceSection: some View {
        settingsSection(title: L("settings.appearance"), icon: "paintbrush.fill", color: Color(hex: "#A855F7")!) {
            // Color theme picker
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "swatchpalette.fill")
                        .frame(width: 24)
                        .foregroundStyle(Color.walletPrimary)
                    Text(L("settings.colorTheme"))
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // 7-color grid (2 rows of 4 + 3 — use LazyVGrid)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            themeKey = theme.rawValue
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(theme.primaryColor)
                                        .frame(width: 38, height: 38)
                                    if themeKey == theme.rawValue {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 2.5)
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "checkmark")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                Text(theme.displayName)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(themeKey == theme.rawValue ? Color.walletPrimary : .secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .buttonStyle(.plain)
                        .animation(.springy, value: themeKey)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Divider().padding(.horizontal)

            // Personality picker
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "theatermasks.fill")
                        .frame(width: 24)
                        .foregroundStyle(Color(hex: "#EC4899")!)
                    Text(L("settings.personality"))
                        .font(.body)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                HStack(spacing: 12) {
                    ForEach(AppPersonality.allCases) { p in
                        Button {
                            personalityKey = p.rawValue
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            VStack(spacing: 6) {
                                Text(p.emoji)
                                    .font(.system(size: 28))
                                Text(p.displayName)
                                    .font(.caption)
                                    .fontWeight(personalityKey == p.rawValue ? .semibold : .regular)
                                    .foregroundStyle(personalityKey == p.rawValue ? Color.walletPrimary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(personalityKey == p.rawValue ? Color.walletPrimary.opacity(0.12) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(personalityKey == p.rawValue ? Color.walletPrimary : Color.secondary.opacity(0.2), lineWidth: 1.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.springy, value: personalityKey)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            Divider().padding(.horizontal)

            // Color scheme (light/dark/system)
            settingsRow(icon: "circle.lefthalf.filled", title: L("settings.colorSchemeRow")) {
                Picker("", selection: $colorSchemeRaw) {
                    Text(L("settings.systemScheme")).tag("system")
                    Text(L("settings.lightScheme")).tag("light")
                    Text(L("settings.darkScheme")).tag("dark")
                }
                .pickerStyle(.menu)
                .tint(Color.walletPrimary)
            }
        }
    }

    private var preferencesSection: some View {
        settingsSection(title: L("settings.preferences"), icon: "gearshape.fill", color: .secondary) {
            settingsRow(icon: "bell.fill", title: L("settings.budgetAlerts")) {
                Toggle("", isOn: $notificationsEnabled)
                    .tint(Color.walletPrimary)
                    .labelsHidden()
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "faceid", title: L("settings.faceID")) {
                Toggle("", isOn: $biometricEnabled)
                    .tint(Color.walletPrimary)
                    .labelsHidden()
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "globe", title: L("settings.language")) {
                Picker("", selection: $appLanguage) {
                    Text(L("common.english")).tag("en")
                    Text(L("common.spanish")).tag("es")
                }
                .pickerStyle(.menu)
                .tint(Color.walletPrimary)
            }
        }
    }

    private var dataSection: some View {
        settingsSection(title: L("settings.data"), icon: "externaldrive.fill", color: .blue) {
            settingsRow(icon: "square.and.arrow.up", title: L("settings.exportCSV")) {
                Button {
                    exportCSV()
                } label: {
                    Text(L("settings.export"))
                        .foregroundStyle(.blue)
                }
            }

            Divider().padding(.horizontal)

            settingsRow(icon: "trash.fill", title: L("settings.deleteAll")) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text(L("settings.delete"))
                        .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog(L("settings.deleteAll"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L("settings.deleteEverything"), role: .destructive) { deleteAll() }
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
                    Text(L("settings.monthlyLimit"))
                        .font(.headline)
                    AmountTextField(amount: $amount, currency: "USD")
                        .padding(20)
                        .glassCard()
                }

                Button(L("common.save")) {
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
                .foregroundStyle(.white)
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle(L("settings.setBudget"))
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
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
