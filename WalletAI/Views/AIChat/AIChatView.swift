import SwiftUI
import SwiftData

struct AIChatView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var budgets: [Budget]

    @State private var deepSeekService = DeepSeekService()
    @State private var speechService = SpeechRecognitionService()
    @State private var messages: [AIMessage] = []
    @State private var inputText: String = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var showAPIKeyPrompt = false
    @Namespace private var bottomID

    private var currency: String { budgets.first?.currency ?? "USD" }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if messages.isEmpty {
                                welcomeCard
                            }
                            ForEach(messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                            if deepSeekService.isLoading {
                                typingIndicator
                            }
                            Color.clear.frame(height: 80).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear { scrollProxy = proxy }
                }

                // Input bar
                inputBar
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Set API Key") { showAPIKeyPrompt = true }
                        Button("Clear Chat") { messages = [] }
                        Button("Financial Summary") { askQuickQuestion("Give me a detailed summary of my finances this month") }
                        Button("Saving Tips") { askQuickQuestion("Based on my spending, give me 3 specific tips to save more money") }
                        Button("Biggest Expenses") { askQuickQuestion("What are my biggest expenses and how can I reduce them?") }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(Color.walletPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAPIKeyPrompt) {
                APIKeySetupView(service: deepSeekService)
            }
            .onAppear {
                if messages.isEmpty && deepSeekService.hasAPIKey {
                    sendWelcomeMessage()
                }
            }
            // When Whisper finishes transcribing, populate the text field
            .onChange(of: speechService.isTranscribing) { _, isTranscribing in
                if !isTranscribing, !speechService.transcript.isEmpty {
                    inputText = speechService.transcript
                    speechService.transcript = ""
                }
            }
            .keyboardDoneButton()
        }
    }

    // MARK: - Welcome Card

    private var welcomeCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.walletPrimary.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.walletPrimary)
            }

            VStack(spacing: 8) {
                Text("Meet your AI Finance Assistant")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Ask anything about your spending, get insights, or let me help you track expenses via voice.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !deepSeekService.hasAPIKey {
                Button {
                    showAPIKeyPrompt = true
                } label: {
                    Label("Set Up Groq API Key", systemImage: "key.fill")
                        .font(.headline)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular.tint(Color.walletPrimary).interactive(), in: .rect(cornerRadius: 16))
                        .foregroundStyle(Color.walletPrimary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                Text("Quick Questions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(quickQuestions, id: \.self) { q in
                    Button { askQuickQuestion(q) } label: {
                        Text(q)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .glassCard()
        .padding(.top, 20)
    }

    private let quickQuestions = [
        "How much have I spent this month?",
        "What's my biggest spending category?",
        "Am I over budget?",
        "Give me 3 tips to save more money",
    ]

    // MARK: - Input Bar

    private var inputBar: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                TextField("Ask about your finances...", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())

                Button {
                    if speechService.isListening || speechService.isTranscribing {
                        if speechService.isListening { speechService.stopListening() }
                    } else if inputText.isEmpty {
                        handleMicTap()
                    } else {
                        send()
                    }
                } label: {
                    Group {
                        if speechService.isTranscribing {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: speechService.isListening ? "stop.circle.fill"
                                             : (inputText.isEmpty ? "mic.fill" : "arrow.up.circle.fill"))
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(speechService.isListening ? Color.red : Color.walletPrimary, in: Circle())
                    .animation(.springy, value: speechService.isListening)
                }
                .disabled(deepSeekService.isLoading)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .padding(.bottom, 20)
        }
    }

    private var typingIndicator: some View {
        HStack(alignment: .bottom) {
            ZStack {
                Circle()
                    .fill(Color.walletPrimary.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.walletPrimary)
            }

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(1.0)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                            value: deepSeekService.isLoading
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)

            Spacer()
        }
    }

    // MARK: - Actions

    private func sendWelcomeMessage() {
        let welcome = AIMessage(
            role: .assistant,
            content: "Hi! I'm your WalletAI assistant. I can see your transactions and help with spending insights. What would you like to know?"
        )
        messages = [welcome]
    }

    private func askQuickQuestion(_ q: String) {
        inputText = q
        send()
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        let userMsg = AIMessage(role: .user, content: text)
        messages.append(userMsg)

        scrollToBottom()

        guard deepSeekService.hasAPIKey else {
            let reply = AIMessage(role: .assistant, content: "Please add your Groq API key — tap the ⋯ menu above.")
            messages.append(reply)
            return
        }

        // Build context-aware message list
        let systemPrompt = deepSeekService.buildSystemPrompt(
            transactions: Array(transactions.prefix(50)),
            budget: budgets.first
        )
        let systemMsg = AIMessage(role: .system, content: systemPrompt)
        let history = Array(messages.suffix(Constants.Limits.aiMessageHistory))

        var streamingMsg = AIMessage(role: .assistant, content: "", isStreaming: true)
        messages.append(streamingMsg)
        let streamingIndex = messages.count - 1

        Task {
            await deepSeekService.streamChat(
                messages: [systemMsg] + history,
                onChunk: { chunk in
                    streamingMsg.content += chunk
                    messages[streamingIndex] = streamingMsg
                    scrollToBottom()
                },
                onComplete: {
                    streamingMsg.isStreaming = false
                    if streamingMsg.content.isEmpty {
                        streamingMsg.content = deepSeekService.error ?? "No response received. Check your API key."
                    }
                    messages[streamingIndex] = streamingMsg
                }
            )
        }
    }

    private func scrollToBottom() {
        withAnimation(.smooth) {
            scrollProxy?.scrollTo("bottom", anchor: .bottom)
        }
    }

    private func handleMicTap() {
        Task { try? await speechService.startListening() }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AIMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                ZStack {
                    Circle()
                        .fill(Color.walletPrimary.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.walletPrimary)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content.isEmpty ? "▌" : message.content)
                    .font(.body)
                    .foregroundStyle(isUser ? Color.white : Color.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser ? Color.walletPrimary : Color(UIColor.secondarySystemBackground),
                        in: UnevenRoundedRectangle(
                            topLeadingRadius: isUser ? 18 : 4,
                            bottomLeadingRadius: 18,
                            bottomTrailingRadius: isUser ? 4 : 18,
                            topTrailingRadius: 18
                        )
                    )

                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - API Key Setup

struct APIKeySetupView: View {
    let service: DeepSeekService
    @Environment(\.dismiss) private var dismiss
    @State private var key: String = ""
    @State private var saved = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Info card
                VStack(spacing: 10) {
                    Text("⚡️")
                        .font(.system(size: 44))
                    Text("Groq AI — Free")
                        .font(.title2.bold())
                    Text("100% free, no credit card needed.\nGet your key at console.groq.com")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("gsk_...", text: $key)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.walletPrimary.opacity(0.3), lineWidth: 1))
                }

                Button {
                    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    service.setAPIKey(trimmed)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: saved ? "checkmark.circle.fill" : "key.fill")
                        Text(saved ? "Saved!" : "Save Key")
                            .font(.headline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(key.isEmpty ? Color.walletPrimary.opacity(0.15) : Color.walletPrimary)
                    .foregroundStyle(key.isEmpty ? Color.walletPrimary : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(key.isEmpty)
                .buttonStyle(.plain)
                .animation(.springy, value: saved)

                Spacer()
            }
            .padding(16)
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle("Setup AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { key = service.apiKey }
        }
    }
}
