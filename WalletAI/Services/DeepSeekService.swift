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
        let totalSpent = transactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
        let totalIncome = transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
        let budgetInfo = budget.map { "Monthly budget: \($0.totalMonthlyLimit.currencyFormatted())" } ?? ""

        let expenses = transactions.filter { $0.isExpense }
        let byCategory = Dictionary(grouping: expenses) { $0.category?.name ?? "Other" }
        let categoryTotals: [(String, Double)] = byCategory.map { ($0.key, $0.value.reduce(0.0) { $0 + $1.amount }) }
        let topCategories = categoryTotals
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { "\($0.0): \($0.1.currencyFormatted())" }
            .joined(separator: ", ")

        // Individual transaction list (most recent 30)
        let txList = transactions.prefix(30).map { t in
            let date = t.date.formatted(.dateTime.month(.abbreviated).day())
            let sign = t.isExpense ? "-" : "+"
            let cat = t.category?.name ?? "Other"
            return "  [\(date)] \(sign)\(t.amount.currencyFormatted()) – \(t.title) (\(cat))"
        }.joined(separator: "\n")

        let personality = AppTheme.current.aiPersonality
        let lang = UserDefaults.standard.string(forKey: "walletai_language") ?? "en"
        let langInstruction = lang == "es"
            ? "Respond in Spanish. Use 'vos' or 'usted' naturally. The user is from El Salvador."
            : "Respond in English."

        return """
        You are WalletAI, a personal finance assistant for users in El Salvador. \
        The primary currency context is USD (El Salvador uses the US dollar). \
        Be aware of local context: pupusas, mercado, transporte, remesas, etc.

        \(langInstruction)

        User's finances this month:
        - Expenses: \(totalSpent.currencyFormatted()), Income: \(totalIncome.currencyFormatted()), Net: \((totalIncome - totalSpent).currencyFormatted())
        \(budgetInfo)
        - Top categories: \(topCategories)

        Recent transactions (you can reference these when answering specific questions):
        \(txList)

        Rules:
        - Keep answers short and direct. 2-4 sentences max unless a detailed breakdown is asked for.
        - Only answer what was asked. Don't volunteer unsolicited advice.
        - Use markdown formatting: **bold** for key numbers/amounts, *italic* for emphasis. Use bullet points for lists.
        - Use at most 1 emoji per message, only when it genuinely helps.
        - Be natural and friendly, not enthusiastic or cringe.
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
