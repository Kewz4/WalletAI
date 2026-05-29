import SwiftUI
import Charts

struct SpendingBarChart: View {
    let data: [(label: String, amount: Double)]
    let currency: String

    var body: some View {
        Chart {
            ForEach(data, id: \.label) { item in
                BarMark(
                    x: .value("Day", item.label),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.walletPrimary.opacity(0.6), .walletPrimary],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(6)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(d.currencyFormatted(currency: currency))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .frame(height: 180)
    }
}

struct CategoryDonutChart: View {
    let data: [(category: String, amount: Double, color: Color)]
    let total: Double
    let currency: String

    var body: some View {
        Chart(data, id: \.category) { item in
            SectorMark(
                angle: .value("Amount", item.amount),
                innerRadius: .ratio(0.6),
                angularInset: 2
            )
            .foregroundStyle(item.color)
            .annotation(position: .overlay) {
                if item.amount / total > 0.1 {
                    Text(item.amount.percentageFormatted() )
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(height: 200)
    }
}
