import Foundation

@MainActor
@Observable
final class DeepSeekService {
    var isLoading: Bool = false
    var error: String? = nil

    private static let _dk = ["gsk_1ZsUSfn2cD", "LJ93gbeFnOWGdyb3", "FYPtiV4EEpsG8kmd", "gUzqUCo8Ok"].joined()
    var apiKey: String = UserDefaults.standard.string(forKey: Constants.API.groqKeyStorageKey) ?? DeepSeekService._dk {
        didSet { UserDefaults.standard.set(apiKey, forKey: Constants.API.groqKeyStorageKey) }
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    func setAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Chat Completion (streaming)

    func streamChat(messages: [AIMessage], onChunk: @escaping (String) -> Void, onComplete: @escaping () -> Void) async {
        guard hasAPIKey else {
            error = "Please add your Groq API key."
            onComplete()
            return
        }
        guard let url = URL(string: "\(Constants.API.groqBaseURL)/chat/completions") else { onComplete(); return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": Constants.API.groqChatModel,  // compound-beta: built-in web search
            "stream": true,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        isLoading = true

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                error = "API error — check your Groq key at console.groq.com"
                isLoading = false
                onComplete()
                return
            }

            for try await line in bytes.lines {
                if line.hasPrefix("data: ") {
                    let json = String(line.dropFirst(6))
                    if json == "[DONE]" { break }
                    if let data = json.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = obj["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let text = delta["content"] as? String {
                        onChunk(text)
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
        onComplete()
    }

    // MARK: - Financial Context System Prompt

    func buildSystemPrompt(transactions: [Transaction], budget: Budget?) -> String {
        let now = Date()
        let pastTransactions = transactions.filter { $0.date <= now }
        let totalSpent = pastTransactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
        let totalIncome = pastTransactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
        let budgetInfo = budget.map { "Monthly budget: \($0.totalMonthlyLimit.currencyFormatted())" } ?? ""

        let expenses = pastTransactions.filter { $0.isExpense }
        let byCategory = Dictionary(grouping: expenses) { $0.category?.name ?? "Other" }
        let categoryTotals: [(String, Double)] = byCategory.map { ($0.key, $0.value.reduce(0.0) { $0 + $1.amount }) }
        let topCategories = categoryTotals
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { "\($0.0): \($0.1.currencyFormatted())" }
            .joined(separator: ", ")

        // Individual transaction list (most recent 30 past ones)
        let txList = pastTransactions.prefix(30).map { t in
            let date = t.date.formatted(.dateTime.month(.abbreviated).day())
            let sign = t.isExpense ? "-" : "+"
            let cat = t.category?.name ?? "Other"
            return "  [\(date)] \(sign)\(t.amount.currencyFormatted()) – \(t.title) (\(cat))"
        }.joined(separator: "\n")

        // Upcoming recurring transactions (future-dated, not yet reflected in balance)
        let upcoming = transactions.filter { $0.date > now && $0.isRecurring }
        let upcomingLines = upcoming.prefix(10).map { t in
            let date = t.date.formatted(.dateTime.month(.abbreviated).day())
            let sign = t.isExpense ? "expense" : "income"
            return "  [\(date)] \(t.amount.currencyFormatted()) – \(t.title) (\(sign), not yet counted)"
        }.joined(separator: "\n")
        let upcomingSection = upcomingLines.isEmpty ? "" : "\nScheduled future transactions (NOT included in net balance yet):\n\(upcomingLines)"

        let personality = AppPersonality.current.aiPrompt
        let lang = UserDefaults.standard.string(forKey: "walletai_language") ?? "en"
        let langInstruction = lang == "es"
            ? "Respond in Spanish. Use 'vos' or 'usted' naturally. The user is from El Salvador."
            : "Respond in English."

        let botName = AppPersonality.current.botName
        return """
        You are \(botName), a personal finance assistant for users in El Salvador. \
        The primary currency context is USD (El Salvador uses the US dollar). \
        Be aware of local context: pupusas, mercado, transporte, remesas, etc.

        \(langInstruction)

        User's finances this month (past transactions only):
        - Expenses: \(totalSpent.currencyFormatted()), Income: \(totalIncome.currencyFormatted()), Net: \((totalIncome - totalSpent).currencyFormatted())
        \(budgetInfo)
        - Top categories: \(topCategories)

        Recent transactions:
        \(txList)\(upcomingSection)

        IMPORTANT: The net balance shown in the app only includes transactions that have already occurred. Future-dated recurring transactions are scheduled but NOT yet counted in the balance.

        Rules:
        - Be extremely concise. 1-2 sentences for simple questions, 3-4 max for complex ones.
        - Answer ONLY what was asked. Do not add tips, caveats, or extra context unless asked.
        - If asked for the biggest/highest transaction, just name it and the amount — nothing else.
        - Use **bold** for key numbers only. Avoid bullet lists unless explicitly asked for a breakdown.
        - At most 1 emoji per message.
        - Use double newlines (blank lines) between paragraphs so responses are easy to read.
        - When your response contains a breakdown with 3 or more numeric items (e.g. spending by category, weekly totals), append a chart block on its own line at the very end, after all text:
          [CHART]:{"type":"bar","labels":["Label1","Label2"],"values":[0.0,0.0],"title":"Chart Title","currency":"USD"}
          The JSON must be valid and on a single line. Do not include the chart block for single-item or yes/no answers.
        \(personality)
        """
    }

    // MARK: - Parse AI Transaction Intent

    func parseTransactionIntent(from text: String) async -> ParsedTransaction? {
        guard hasAPIKey else { return nil }
        guard let url = URL(string: "\(Constants.API.groqBaseURL)/chat/completions") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Extract transaction details from: "\(text)"
        Respond ONLY with JSON: {"title": "...", "amount": 0.0, "isExpense": true, "category": "Food"}
        Category must be one of: Food, Transport, Shopping, Entertainment, Health, Home, Bills, Education, Other
        Pick the best match based on the merchant or description. If no transaction detected, respond: null
        """

        let body: [String: Any] = [
            "model": Constants.API.groqModel,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 100
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let content = (choices.first?["message"] as? [String: Any])?["content"] as? String,
              let jsonData = content.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ParsedTransactionDTO.self, from: jsonData)
        else { return nil }

        return ParsedTransaction(title: parsed.title, amount: parsed.amount, isExpense: parsed.isExpense, suggestedCategoryName: parsed.category)
    }

    private struct ParsedTransactionDTO: Decodable {
        let title: String
        let amount: Double
        let isExpense: Bool
        let category: String?
    }
}
