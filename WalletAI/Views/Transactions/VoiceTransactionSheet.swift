import SwiftUI
import SwiftData

struct VoiceTransactionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]
    @Query private var budgets: [Budget]

    @State private var speechService = SpeechRecognitionService()
    @State private var deepSeekService = DeepSeekService()
    @State private var parsedTransaction: ParsedTransaction? = nil
    @State private var showConfirm = false
    @State private var confirmedTitle = ""
    @State private var confirmedAmount: Double = 0
    @State private var selectedCategory: Category? = nil
    @State private var status: Status = .idle
    @Namespace private var glassNS

    enum Status {
        case idle, listening, processing, confirming
    }

    private var currency: String { budgets.first?.currency ?? "USD" }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.walletBackground.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Status display
                    statusDisplay

                    // Transcript
                    if !speechService.transcript.isEmpty {
                        transcriptBubble
                    }

                    // Parsed preview
                    if status == .confirming, let tx = parsedTransaction {
                        confirmationCard(tx)
                    }

                    Spacer()

                    // Voice button
                    VoiceInputButton(
                        isListening: Binding(get: { speechService.isListening }, set: { _ in }),
                        transcript: speechService.transcript,
                        onTap: { try await speechService.startListening() },
                        onStop: {
                            speechService.stopListening()
                            processTranscript()
                        }
                    )

                    Text(hintText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Voice Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: speechService.isListening) { _, isListening in
                withAnimation(.springy) {
                    status = isListening ? .listening : .idle
                }
            }
        }
    }

    private var hintText: String {
        switch status {
        case .idle:        return "Tap the mic and say something like\n\"I spent $45 on groceries\""
        case .listening:   return "Listening... tap to stop"
        case .processing:  return "Understanding your transaction..."
        case .confirming:  return "Confirm the details below"
        }
    }

    private var statusDisplay: some View {
        ZStack {
            if status == .listening {
                WaveformView(isActive: true)
                    .transition(.scale.combined(with: .opacity))
            } else if status == .processing {
                ProgressView()
                    .scaleEffect(1.5)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 48))
                    .foregroundStyle(.walletPrimary.opacity(0.4))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 60)
        .animation(.springy, value: status)
    }

    private var transcriptBubble: some View {
        Text(speechService.transcript)
            .font(.body)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func confirmationCard(_ tx: ParsedTransaction) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(tx.isExpense ? "Expense Detected" : "Income Detected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(tx.amount.currencyFormatted(currency: currency))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(tx.isExpense ? .red : .green)

                Text(tx.title)
                    .font(.headline)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories.prefix(8)) { cat in
                        Button {
                            withAnimation(.springy) { selectedCategory = cat }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.iconName)
                                    .font(.caption)
                                Text(cat.name)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .glassEffect(
                                selectedCategory?.id == cat.id
                                    ? .regular.tint(cat.color).interactive()
                                    : .regular.interactive(),
                                in: .capsule
                            )
                            .foregroundStyle(selectedCategory?.id == cat.id ? cat.color : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()

            HStack(spacing: 12) {
                Button("Retry") {
                    withAnimation(.springy) {
                        parsedTransaction = nil
                        status = .idle
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)

                Button("Save") {
                    saveTransaction(tx)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .glassEffect(
                    .regular.tint(tx.isExpense ? .red : .green).interactive(),
                    in: .rect(cornerRadius: 14)
                )
                .foregroundStyle(tx.isExpense ? .red : .green)
                .font(.headline)
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .glassCard()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func processTranscript() {
        guard !speechService.transcript.isEmpty else { return }
        withAnimation(.springy) { status = .processing }

        // First try local parse, then AI enhance
        if let local = speechService.parseTransactionFromSpeech(speechService.transcript) {
            Task {
                // Optionally refine via AI
                let aiResult = await deepSeekService.parseTransactionIntent(from: speechService.transcript)
                await MainActor.run {
                    parsedTransaction = aiResult ?? local
                    selectedCategory = categories.first { $0.name == "Other" }
                    withAnimation(.springy) { status = .confirming }
                }
            }
        } else {
            Task {
                let result = await deepSeekService.parseTransactionIntent(from: speechService.transcript)
                await MainActor.run {
                    if let tx = result {
                        parsedTransaction = tx
                        selectedCategory = categories.first { $0.name == "Other" }
                        withAnimation(.springy) { status = .confirming }
                    } else {
                        withAnimation(.springy) { status = .idle }
                    }
                }
            }
        }
    }

    private func saveTransaction(_ parsed: ParsedTransaction) {
        let tx = Transaction(
            title: parsed.title,
            amount: parsed.amount,
            isExpense: parsed.isExpense,
            category: selectedCategory,
            source: .voice,
            currency: currency
        )
        context.insert(tx)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
