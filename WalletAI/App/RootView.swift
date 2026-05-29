import SwiftUI
import SwiftData
import LocalAuthentication

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(Constants.Storage.biometricEnabledKey) private var biometricEnabled = false
    @State private var selectedTab: Tab = .dashboard
    @State private var isLocked = false
    @State private var authError: String? = nil
    @Environment(\.scenePhase) private var scenePhase

    enum Tab: String, CaseIterable {
        case dashboard, transactions, ai, categories, settings

        var icon: String {
            switch self {
            case .dashboard:    return "chart.pie.fill"
            case .transactions: return "list.bullet.rectangle.fill"
            case .ai:           return "sparkles"
            case .categories:   return "square.grid.2x2.fill"
            case .settings:     return "gearshape.fill"
            }
        }

        var label: String {
            switch self {
            case .dashboard:    return "Dashboard"
            case .transactions: return "Transactions"
            case .ai:           return "AI"
            case .categories:   return "Categories"
            case .settings:     return "Settings"
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
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background && biometricEnabled {
                        isLocked = true
                    } else if phase == .active && biometricEnabled && isLocked {
                        authenticate()
                    }
                }
                .onAppear {
                    if biometricEnabled { isLocked = true; authenticate() }
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

            SettingsView()
                .tag(Tab.settings)
                .tabItem { Label(Tab.settings.label, systemImage: Tab.settings.icon) }
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
                    .glassEffect(.regular.tint(Color.walletPrimary).interactive(), in: .rect(cornerRadius: 20))
                    .foregroundStyle(Color.walletPrimary)
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
