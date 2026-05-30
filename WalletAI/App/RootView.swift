import SwiftUI
import SwiftData
import LocalAuthentication

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(Constants.Storage.biometricEnabledKey) private var biometricEnabled = false
    @State private var selectedTab: Tab = .dashboard
    @State private var isLocked = false
    @State private var authError: String? = nil
    @State private var hasAttemptedInitialAuth = false
    @State private var applePayObserver = ApplePayObserver()
    @Environment(\.scenePhase) private var scenePhase

    enum Tab: String, CaseIterable {
        case dashboard, transactions, ai, categories

        var icon: String {
            switch self {
            case .dashboard:    return "chart.pie.fill"
            case .transactions: return "list.bullet.rectangle.fill"
            case .ai:           return "sparkles"
            case .categories:   return "square.grid.2x2.fill"
            }
        }

        var label: String {
            switch self {
            case .dashboard:    return "Dashboard"
            case .transactions: return "Transactions"
            case .ai:           return "AI"
            case .categories:   return "Categories"
            }
        }
    }

    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(isComplete: $hasCompletedOnboarding)
        } else if biometricEnabled && isLocked {
            lockScreen
        } else {
            mainTabs
                .onOpenURL { url in applePayObserver.handleShortcutURL(url) }
                .sheet(isPresented: $applePayObserver.showTransactionPrompt) {
                    if let pending = applePayObserver.pendingTransaction {
                        AddTransactionView(title: pending.title, amount: pending.amount, source: .applePay)
                            .onDisappear { applePayObserver.pendingTransaction = nil }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background && biometricEnabled {
                        isLocked = true
                    } else if phase == .active && biometricEnabled && isLocked {
                        authenticate()
                    }
                }
                .onAppear {
                    guard biometricEnabled, !hasAttemptedInitialAuth else { return }
                    hasAttemptedInitialAuth = true
                    isLocked = true
                    authenticate()
                }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tag(Tab.dashboard)
                .tabItem { Label(Tab.dashboard.label, systemImage: Tab.dashboard.icon) }

            TransactionListView()
                .tag(Tab.transactions)
                .tabItem { Label(Tab.transactions.label, systemImage: Tab.transactions.icon) }

            AIChatView()
                .tag(Tab.ai)
                .tabItem { Label(Tab.ai.label, systemImage: Tab.ai.icon) }

            CategoriesView()
                .tag(Tab.categories)
                .tabItem { Label(Tab.categories.label, systemImage: Tab.categories.icon) }
        }
        .tint(Color.walletPrimary)
    }

    private var lockScreen: some View {
        ZStack {
            Color.walletBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.walletPrimary.opacity(0.15))
                        .frame(width: 110, height: 110)
                        .glassEffect(.regular.tint(Color.walletPrimary), in: .circle)
                    Text("🔒")
                        .font(.system(size: 48))
                }

                VStack(spacing: 8) {
                    Text("WalletAI is Locked")
                        .font(.title2.bold())
                    Text("Use Face ID to unlock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let err = authError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                Spacer()

                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.headline)
                        Text("Unlock with Face ID")
                            .font(.headline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(Color.walletPrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    private func authenticate() {
        let ctx = LAContext()
        var policyError: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            // Fallback: if device has no biometrics, just unlock
            isLocked = false
            return
        }
        authError = nil
        ctx.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Unlock WalletAI"
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    withAnimation(.springy) { isLocked = false }
                } else {
                    authError = error?.localizedDescription
                }
            }
        }
    }
}
