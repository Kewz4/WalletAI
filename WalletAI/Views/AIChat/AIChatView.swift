import SwiftUI
import SwiftData
import Charts

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

    @AppStorage(Constants.Storage.personalityKey) private var personalityKey = "chill"
    private var botName: String { AppPersonality(rawValue: personalityKey)?.botName ?? "Wall-ie" }
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
            .navigationTitle(botName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(L("ai.menuSetKey")) { showAPIKeyPrompt = true }
                        Button(L("ai.menuClear")) { messages = [] }
                        Button(L("ai.menuSummary")) { askQuickQuestion(L("ai.q1") + " " + L("ai.q2")) }
                        Button(L("ai.menuTips")) { askQuickQuestion(L("ai.q4")) }
                        Button(L("ai.menuBiggest")) { askQuickQuestion(L("ai.q3")) }
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
        }
    }

    // MARK: - Welcome Card

    private var welcomeCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Color.walletPrimary, Color.walletAccent],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Color.walletPrimary.opacity(0.4), radius: 12, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text(botName)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(L("ai.welcomeHint"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !deepSeekService.hasAPIKey {
                Button {
                    showAPIKeyPrompt = true
                } label: {
                    Label(L("ai.setupKey"), systemImage: "key.fill")
                        .font(.headline)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular.tint(Color.walletPrimary).interactive(), in: .rect(cornerRadius: 16))
                        .foregroundStyle(Color.walletPrimary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                Text(L("ai.quickQuestions"))
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

    private var quickQuestions: [String] {
        [L("ai.q1"), L("ai.q2"), L("ai.q3"), L("ai.q4")]
    }

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

                TextField(L("ai.inputPlaceholder"), text: $inputText, axis: .vertical)
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

    // MARK: - Actions

    private func sendWelcomeMessage() {
        let name = botName
        let welcome = AIMessage(role: .assistant, content: "Hi! I'm \(name), your finance assistant. I can see your transactions and help with spending insights. What would you like to know?")
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
            let reply = AIMessage(role: .assistant, content: L("ai.noKey"))
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
        scrollToBottom()

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
                    let (cleanContent, chart) = parseChartPayload(from: streamingMsg.content)
                    streamingMsg.content = cleanContent
                    streamingMsg.chartPayload = chart
                    if streamingMsg.content.isEmpty {
                        streamingMsg.content = deepSeekService.error ?? "No response received. Check your API key."
                    }
                    messages[streamingIndex] = streamingMsg
                }
            )
        }
    }

    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.smooth) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func handleMicTap() {
        Task { try? await speechService.startListening() }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func parseChartPayload(from text: String) -> (String, AIChartData?) {
        let marker = "[CHART]:"
        guard let range = text.range(of: marker) else { return (text, nil) }
        let before = String(text[text.startIndex..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonStr = String(text[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n").first ?? ""
        guard let data = jsonStr.data(using: .utf8),
              let chart = try? JSONDecoder().decode(AIChartData.self, from: data) else {
            return (before.isEmpty ? text : before, nil)
        }
        return (before, chart)
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
                .alignmentGuide(.bottom) { d in d[.bottom] }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // Main bubble
                VStack(alignment: .leading, spacing: 0) {
                    if !isUser && message.content.isEmpty {
                        BouncingDotsView()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                    } else {
                        paragraphBody(message.content)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                }
                .background(
                    isUser ? Color.walletPrimary : Color(UIColor.secondarySystemBackground),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: isUser ? 18 : 4,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: isUser ? 4 : 18,
                        topTrailingRadius: 18
                    )
                )
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.content
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(L("common.copy"), systemImage: "doc.on.doc")
                    }
                }

                // Chart (AI only)
                if !isUser, let chart = message.chartPayload {
                    AIChartView(chart: chart)
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 16))
                }

                Text(message.timestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    // Split on double newline → separate Text views with spacing
    @ViewBuilder
    private func paragraphBody(_ raw: String) -> some View {
        let paragraphs = raw
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if paragraphs.count <= 1 {
            markdownText(raw)
                .foregroundStyle(isUser ? Color.white : Color.primary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                    markdownText(para)
                        .foregroundStyle(isUser ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func markdownText(_ raw: String) -> Text {
        var attributed = AttributedString()
        let chars = Array(raw)
        var i = 0
        var plain = ""

        func flush() {
            if !plain.isEmpty {
                attributed.append(AttributedString(plain))
                plain = ""
            }
        }

        while i < chars.count {
            if i + 1 < chars.count && chars[i] == "*" && chars[i+1] == "*" {
                var j = i + 2
                while j + 1 < chars.count && !(chars[j] == "*" && chars[j+1] == "*") { j += 1 }
                if j + 1 < chars.count {
                    flush()
                    var seg = AttributedString(String(chars[(i+2)..<j]))
                    seg.font = .body.bold()
                    attributed.append(seg)
                    i = j + 2
                } else { plain.append(chars[i]); i += 1 }
            } else if chars[i] == "*" {
                var j = i + 1
                while j < chars.count && chars[j] != "*" { j += 1 }
                if j < chars.count {
                    flush()
                    var seg = AttributedString(String(chars[(i+1)..<j]))
                    seg.font = .body.italic()
                    attributed.append(seg)
                    i = j + 1
                } else { plain.append(chars[i]); i += 1 }
            } else {
                plain.append(chars[i]); i += 1
            }
        }
        flush()
        return Text(attributed).font(.body)
    }
}

// MARK: - AI Chart View

let chartPalette: [Color] = [
    .walletPrimary, Color(hex: "#00B894")!, Color(hex: "#E17055")!,
    Color(hex: "#6C5CE7")!, Color(hex: "#FDCB6E")!, Color(hex: "#0984E3")!,
    Color(hex: "#FF6B6B")!, Color(hex: "#A855F7")!
]

struct AIChartView: View {
    let chart: AIChartData
    var isExpanded: Bool = false
    @State private var showExpanded = false

    private var pairs: [(String, Double)] { Array(zip(chart.labels, chart.values)) }
    private var sym: String { chart.currency == "USD" ? "$" : (chart.currency ?? "") }
    private var total: Double { max(chart.values.reduce(0, +), 0.01) }
    private var barH: CGFloat { isExpanded ? 240 : 160 }
    private var pieH: CGFloat { isExpanded ? 220 : 160 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let title = chart.title {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !isExpanded {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            switch chart.type {
            case .bar:  barChart
            case .pie:  pieChart
            case .line: lineChart
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if !isExpanded { showExpanded = true } }
        .sheet(isPresented: $showExpanded) {
            ExpandedChartSheet(chart: chart)
        }
    }

    // MARK: Bar
    private var barChart: some View {
        Chart {
            ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                BarMark(x: .value("Label", pair.0), y: .value("Amount", pair.1))
                    .foregroundStyle(chartPalette[idx % chartPalette.count].gradient)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text("\(sym)\(Int(pair.1))")
                            .font(.system(size: isExpanded ? 10 : 9, weight: .semibold))
                            .foregroundStyle(chartPalette[idx % chartPalette.count])
                    }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.caption2) } }
        .frame(maxWidth: .infinity)
        .frame(height: barH)
    }

    // MARK: Pie / Donut — vertical layout so labels are never clipped
    private var pieChart: some View {
        VStack(spacing: 12) {
            Chart {
                ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                    SectorMark(
                        angle: .value("Amount", pair.1),
                        innerRadius: .ratio(0.52),
                        angularInset: 2.5
                    )
                    .foregroundStyle(chartPalette[idx % chartPalette.count])
                    .cornerRadius(5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: pieH)

            // Full-width legend grid — 2 columns, no truncation
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(chartPalette[idx % chartPalette.count])
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pair.0)
                                .font(.caption2.weight(.medium))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(sym)\(Int(pair.1)) · \(Int(pair.1 / total * 100))%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    // MARK: Line
    private var lineChart: some View {
        Chart {
            ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                LineMark(x: .value("Label", pair.0), y: .value("Amount", pair.1))
                    .foregroundStyle(Color.walletPrimary)
                    .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Label", pair.0), y: .value("Amount", pair.1))
                    .foregroundStyle(Color.walletPrimary.opacity(0.12).gradient)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Label", pair.0), y: .value("Amount", pair.1))
                    .foregroundStyle(Color.walletPrimary)
                    .symbolSize(isExpanded ? 50 : 30)
                    .annotation(position: .top) {
                        Text("\(sym)\(Int(pair.1))")
                            .font(.system(size: isExpanded ? 10 : 9, weight: .semibold))
                            .foregroundStyle(Color.walletPrimary)
                    }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.caption2) } }
        .frame(maxWidth: .infinity)
        .frame(height: barH)
    }
}

// MARK: - Expanded Chart Sheet

struct ExpandedChartSheet: View {
    let chart: AIChartData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    AIChartView(chart: chart, isExpanded: true)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    if !chart.labels.isEmpty {
                        let pairs = Array(zip(chart.labels, chart.values))
                        let sym = chart.currency == "USD" ? "$" : (chart.currency ?? "")
                        let total = max(chart.values.reduce(0, +), 0.01)

                        VStack(spacing: 0) {
                            ForEach(Array(pairs.enumerated()), id: \.offset) { idx, pair in
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(chartPalette[idx % chartPalette.count])
                                        .frame(width: 10, height: 10)
                                    Text(pair.0)
                                        .font(.subheadline)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(sym)\(String(format: "%.2f", pair.1))")
                                            .font(.subheadline.bold())
                                        Text("\(Int(pair.1 / total * 100))%")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                if idx < pairs.count - 1 {
                                    Divider().padding(.leading, 42)
                                }
                            }
                        }
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color.walletBackground.ignoresSafeArea())
            .navigationTitle(chart.title ?? "Chart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Bouncing Dots Typing Indicator

struct BouncingDotsView: View {
    @State private var up0 = false
    @State private var up1 = false
    @State private var up2 = false

    private let bounce = Animation.easeInOut(duration: 0.38).repeatForever(autoreverses: true)

    var body: some View {
        HStack(spacing: 5) {
            dot(up: up0)
            dot(up: up1)
            dot(up: up2)
        }
        .onAppear {
            withAnimation(bounce)                       { up0 = true }
            withAnimation(bounce.delay(0.14))           { up1 = true }
            withAnimation(bounce.delay(0.28))           { up2 = true }
        }
    }

    private func dot(up: Bool) -> some View {
        Circle()
            .fill(Color.secondary.opacity(0.65))
            .frame(width: 7, height: 7)
            .offset(y: up ? -5 : 0)
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
                    Text("🤖")
                        .font(.system(size: 44))
                    Text(L("settings.aiSection"))
                        .font(.title2.bold())
                    Text("Paste your API key below to enable AI features.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 6) {
                    Text(L("settings.groqKey"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("API Key", text: $key)
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
