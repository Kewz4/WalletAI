import SwiftUI
import Foundation

// MARK: - Color Extensions

extension Color {
    // Theme-aware colors — update automatically when AppTheme.current changes
    static var walletPrimary:    Color { AppTheme.current.primaryColor }
    static var walletAccent:     Color { AppTheme.current.accentColor }
    // System colors — unchanged across themes, light/dark handled by asset catalog
    static let walletSecondary  = Color("WalletSecondary",  bundle: nil)
    static let walletBackground = Color("WalletBackground", bundle: nil)
    static let walletSurface    = Color("WalletSurface",    bundle: nil)
}

// Allows `.walletPrimary` in .foregroundStyle() / .tint() / .glassEffect().tint()
extension ShapeStyle where Self == Color {
    static var walletPrimary:    Color { AppTheme.current.primaryColor }
    static var walletAccent:     Color { AppTheme.current.accentColor }
    static var walletSecondary:  Color { Color("WalletSecondary")  }
    static var walletBackground: Color { Color("WalletBackground") }
    static var walletSurface:    Color { Color("WalletSurface")    }
}

extension Color {

    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        guard hex.count == 6, let intVal = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red:   Double((intVal >> 16) & 0xFF) / 255,
            green: Double((intVal >> 8)  & 0xFF) / 255,
            blue:  Double(intVal         & 0xFF) / 255
        )
    }

    var hex: String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    func luminance() -> Double {
        let c = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: nil)
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    }

    var adaptedForeground: Color {
        luminance() > 0.5 ? .black : .white
    }
}

// MARK: - Double Formatting

extension Double {
    func currencyFormatted(currency: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    func percentageFormatted() -> String {
        String(format: "%.1f%%", self * 100)
    }
}

// MARK: - Date Extensions

extension Date {
    var startOfMonth: Date {
        Calendar.current.dateInterval(of: .month, for: self)!.start
    }

    var endOfMonth: Date {
        Calendar.current.dateInterval(of: .month, for: self)!.end
    }

    var monthYearString: String {
        formatted(.dateTime.month(.wide).year())
    }

    var shortMonthString: String {
        formatted(.dateTime.month(.abbreviated))
    }

    func isSameMonth(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .month)
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(cornerRadius: CGFloat = 20, tint: Color? = nil) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }

    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    func conditionalModifier<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        Group {
            if condition { transform(self) }
            else { self }
        }
    }

    /// Adds a "Done" button above the keyboard on every screen that has text fields.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
                .foregroundStyle(Color.walletPrimary)
            }
        }
    }
}

// MARK: - Animation

extension Animation {
    static let springy = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let smooth = Animation.easeInOut(duration: 0.3)
}
