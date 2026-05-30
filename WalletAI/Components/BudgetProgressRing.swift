import SwiftUI

struct BudgetProgressRing: View {
    let progress: Double
    let spent: Double
    let total: Double
    let currency: String
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    private var ringColor: Color {
        switch progress {
        case ..<0.75: return .green
        case ..<0.9:  return .orange
        default:      return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: size * 0.08)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.6), ringColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animatedProgress)

            VStack(spacing: 2) {
                Text(spent.currencyFormatted(currency: currency))
                    .font(.system(size: size * 0.14, weight: .bold, design: .rounded))

                Text("of \(total.currencyFormatted(currency: currency))")
                    .font(.system(size: size * 0.09, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(progress.percentageFormatted())
                    .font(.system(size: size * 0.1, weight: .semibold, design: .rounded))
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            animatedProgress = min(progress, 1.0)
        }
        .onChange(of: progress) { _, new in
            withAnimation { animatedProgress = min(new, 1.0) }
        }
    }
}

struct LinearBudgetBar: View {
    let progress: Double
    let category: Category
    @State private var animated: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    if category.iconName.contains(".") {
                        Image(systemName: category.iconName)
                            .font(.subheadline)
                    } else {
                        Text(category.iconName)
                            .font(.subheadline)
                    }
                    Text(category.name)
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(category.color)

                Spacer()

                if let budget = category.monthlyBudget {
                    Text("\(category.totalSpent().currencyFormatted()) / \(budget.currencyFormatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(category.color.opacity(0.15))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [category.color.opacity(0.7), category.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * animated, height: 8)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: animated)
                }
            }
            .frame(height: 8)
        }
        .onAppear { animated = min(progress, 1.0) }
        .onChange(of: progress) { _, new in withAnimation { animated = min(new, 1.0) } }
    }
}
