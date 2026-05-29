import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedTab: Tab = .dashboard

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
        } else {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(Tab.dashboard)
                    .tabItem {
                        Label(Tab.dashboard.label, systemImage: Tab.dashboard.icon)
                    }

                TransactionListView()
                    .tag(Tab.transactions)
                    .tabItem {
                        Label(Tab.transactions.label, systemImage: Tab.transactions.icon)
                    }

                AIChatView()
                    .tag(Tab.ai)
                    .tabItem {
                        Label(Tab.ai.label, systemImage: Tab.ai.icon)
                    }

                CategoriesView()
                    .tag(Tab.categories)
                    .tabItem {
                        Label(Tab.categories.label, systemImage: Tab.categories.icon)
                    }

                SettingsView()
                    .tag(Tab.settings)
                    .tabItem {
                        Label(Tab.settings.label, systemImage: Tab.settings.icon)
                    }
            }
            .tint(.walletPrimary)
        }
    }
}
