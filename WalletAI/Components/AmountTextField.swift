import SwiftUI

struct AmountTextField: View {
    @Binding var amount: Double
    let currency: String
    var textColor: Color = .primary
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private var symbol: String {
        Locale.current.currencySymbol ?? "$"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Spacer(minLength: 0)

            Text(symbol)
                .font(Font.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor.opacity(0.7))
                .padding(.trailing, 3)

            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
                .fixedSize()
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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
