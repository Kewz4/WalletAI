import SwiftUI

struct AmountTextField: View {
    @Binding var amount: Double
    let currency: String
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(Locale.current.currencySymbol ?? "$")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            TextField("0.00", text: $text)
                .keyboardType(.decimalPad)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                    if filtered != newValue { text = filtered }
                    amount = Double(text) ?? 0
                }
                .onChange(of: amount) { _, new in
                    if !isFocused {
                        text = new == 0 ? "" : String(format: "%.2f", new)
                    }
                }
                .onAppear {
                    text = amount == 0 ? "" : String(format: "%.2f", amount)
                }
        }
        .multilineTextAlignment(.center)
    }
}
