import SwiftUI

struct VoiceInputButton: View {
    @Binding var isListening: Bool
    let transcript: String
    let onTap: () async throws -> Void
    let onStop: () -> Void

    @State private var waveScale: CGFloat = 1.0
    @State private var ripple1: CGFloat = 1.0
    @State private var ripple2: CGFloat = 1.0
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 0) {
            Button {
                Task {
                    if isListening { onStop() }
                    else { try? await onTap() }
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                ZStack {
                    if isListening {
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(Color.walletPrimary.opacity(0.3 - Double(i) * 0.08), lineWidth: 2)
                                .scaleEffect(1.0 + CGFloat(i) * 0.4 + (isListening ? 0.2 : 0))
                                .animation(
                                    .easeInOut(duration: 1.0 + Double(i) * 0.2)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                    value: isListening
                                )
                        }
                    }

                    Image(systemName: isListening ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(isListening ? Color.red : Color.walletPrimary)
                        .scaleEffect(isListening ? 1.1 : 1.0)
                        .animation(.springy, value: isListening)
                }
                .frame(width: 64, height: 64)
                .glassEffect(
                    .regular.tint(isListening ? Color.red : Color.walletPrimary).interactive(),
                    in: .circle
                )
                .glassEffectID("voiceBtn", in: namespace)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Waveform Visualizer

struct WaveformView: View {
    let isActive: Bool
    @State private var phases: [CGFloat] = Array(repeating: 0, count: 5)
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.walletPrimary)
                    .frame(width: 4, height: isActive ? 8 + CGFloat(sin(Double(phases[i]))) * 20 : 6)
                    .animation(.easeInOut(duration: 0.15), value: phases[i])
            }
        }
        .frame(height: 40)
        .onReceive(timer) { _ in
            guard isActive else { return }
            for i in 0..<5 {
                phases[i] += CGFloat.random(in: 0.3...0.8)
            }
        }
    }
}
