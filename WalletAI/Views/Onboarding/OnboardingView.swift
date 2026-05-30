import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var currentPage = 0

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
            emoji: "🤖",
            title: "AI Financial Insights",
            subtitle: "Free Groq AI analyzes your spending and gives you personalized tips to save more money.",
            color: Color(hex: "#E17055")!
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
            color: Color(hex: "#0984E3")!
        ),
    ]

    var body: some View {
        ZStack {
            // Full-bleed animated gradient background
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
                    .fill(.white.opacity(0.2))
                    .frame(width: 150, height: 150)
                Circle()
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 150, height: 150)
                Text(page.emoji)
                    .font(.system(size: 72))
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.15), radius: 4)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var bottomControls: some View {
        VStack(spacing: 24) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage ? .white : .white.opacity(0.4))
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                        .animation(.springy, value: currentPage)
                }
            }

            // Next / Get Started button
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
                    Image(systemName: currentPage == pages.count - 1 ? "checkmark" : "arrow.right")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(.white.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(.white)
                .animation(.springy, value: currentPage)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)

            if currentPage > 0 {
                Button("Back") {
                    withAnimation(.springy) { currentPage -= 1 }
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            } else {
                Color.clear.frame(height: 20)
            }
        }
        .padding(.bottom, 52)
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
            LinearGradient(
                colors: [color, color.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [.white.opacity(0.18), .clear],
                center: .init(x: 0.25 + 0.12 * sin(phase), y: 0.25 + 0.12 * cos(phase)),
                startRadius: 0,
                endRadius: 320
            )
            RadialGradient(
                colors: [.black.opacity(0.12), .clear],
                center: .init(x: 0.75 + 0.1 * cos(phase), y: 0.75 + 0.1 * sin(phase)),
                startRadius: 0,
                endRadius: 280
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
        .animation(.easeInOut(duration: 0.6), value: color)
    }
}
