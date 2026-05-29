import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage = 0
    @Namespace private var glassNS

    let pages: [OnboardingPage] = [
        OnboardingPage(
            emoji: "💼",
            title: "Welcome to WalletAI",
            subtitle: "Your intelligent expense tracker powered by AI. Track smarter, spend better.",
            color: Color(hex: "#6C5CE7")!
        ),
        OnboardingPage(
            emoji: "🎙️",
            title: "Voice-Powered Logging",
            subtitle: "Just say \"I spent $45 on groceries\" and WalletAI handles the rest. No typing needed.",
            color: Color(hex: "#00B894")!
        ),
        OnboardingPage(
            emoji: "✨",
            title: "AI Financial Insights",
            subtitle: "DeepSeek AI analyzes your spending and gives you personalized tips to save more money.",
            color: Color(hex: "#FDCB6E")!
        ),
        OnboardingPage(
            emoji: "📲",
            title: "Apple Pay Integration",
            subtitle: "Set up a Shortcut to automatically log transactions every time you use Apple Pay.",
            color: Color(hex: "#FF6B6B")!
        ),
        OnboardingPage(
            emoji: "📊",
            title: "Beautiful Analytics",
            subtitle: "See where your money goes with gorgeous charts and budget tracking, all in one place.",
            color: Color(hex: "#45B7D1")!
        ),
    ]

    var body: some View {
        ZStack {
            // Animated background
            AnimatedMeshBackground(color: pages[currentPage].color)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.springy, value: currentPage)

                // Bottom controls
                bottomControls
            }
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .glassEffect(.regular.tint(page.color), in: .circle)

                Text(page.emoji)
                    .font(.system(size: 64))
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var bottomControls: some View {
        VStack(spacing: 24) {
            // Dots
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? pages[currentPage].color : Color.secondary.opacity(0.3))
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                        .animation(.springy, value: currentPage)
                }
            }

            // Action button
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if currentPage < pages.count - 1 {
                    withAnimation(.springy) { currentPage += 1 }
                } else {
                    withAnimation(.springy) { isComplete = true }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                        .font(.headline.bold())
                    Text(currentPage == pages.count - 1 ? "✅" : "➡️")
                        .font(.body)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(pages[currentPage].color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(pages[currentPage].color.opacity(0.4), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(pages[currentPage].color)
                .animation(.springy, value: currentPage)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)

            if currentPage > 0 {
                Button("Back") {
                    withAnimation(.springy) { currentPage -= 1 }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 48)
    }
}

struct OnboardingPage {
    let emoji: String
    let title: String
    let subtitle: String
    let color: Color
}

struct AnimatedMeshBackground: View {
    let color: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            Color(.systemBackground)
            RadialGradient(
                colors: [color.opacity(0.3), color.opacity(0.0)],
                center: .init(x: 0.3 + 0.1 * sin(phase), y: 0.3 + 0.1 * cos(phase)),
                startRadius: 0,
                endRadius: 400
            )
            RadialGradient(
                colors: [color.opacity(0.2), color.opacity(0.0)],
                center: .init(x: 0.7 + 0.1 * cos(phase), y: 0.7 + 0.1 * sin(phase)),
                startRadius: 0,
                endRadius: 300
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
        .animation(.easeInOut(duration: 0.5), value: color)
    }
}
