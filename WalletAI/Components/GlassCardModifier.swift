import SwiftUI

struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            }
            .conditionalModifier(tint != nil) { view in
                view.background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint!.opacity(0.08))
                }
            }
    }
}

// MARK: - Native iOS 26 Glass Effect Wrapper

struct GlassEffectView<Content: View>: View {
    let cornerRadius: CGFloat
    let tint: Color?
    @ViewBuilder let content: () -> Content

    init(cornerRadius: CGFloat = 20, tint: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.content = content
    }

    var body: some View {
        content()
            .glassEffect(
                tint != nil
                    ? .regular.tint(tint!).interactive()
                    : .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
    }
}

// MARK: - Pulse Animation

struct PulseEffect: ViewModifier {
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulse ? 1.05 : 1.0)
            .opacity(pulse ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

extension View {
    func pulseEffect() -> some View {
        modifier(PulseEffect())
    }
}
