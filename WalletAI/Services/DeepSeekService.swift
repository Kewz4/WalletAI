import Foundation

@MainActor
@Observable
final class DeepSeekService {
    var isLoading: Bool = false
    var error: String? = nil

    // Stored property so @Observable tracks changes and views re-render
    var apiKey: String = UserDefaults.standard.string(forKey: Constants.API.deepSeekKeyStorageKey) ?? "" {
        didSet { UserDefaults.standard.set(apiKey, forKey: Constants.API.deepSeekKeyStorageKey) }
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    func setAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Chat Completion (streaming)

    func streamChat(messages: [AIMessage], onChunk: @escaping (String) -> Void, onComplete: @escaping () -> Void) async {
        guard hasAPIKey else {
            error = "Please add your DeepSeek API key in Settings."
            onComplete()
            return
        }
        guard let url = URL(string: "\(Constants.API.deepSeekBaseURL)/chat/completions") else { onComplete(); return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": Constants.API.deepSeekModel,
            "stream": true,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        isLoading = true

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                error = "API error. Check your key or try again."
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

        let personality = AppTheme.current.aiPersonality
        return """
        You are WalletAI, an intelligent personal finance assistant integrated into a mobile expense tracking app.

        Current financial snapshot (this month):
        - Total expenses: \(totalSpent.currencyFormatted())
        - Total income: \(totalIncome.currencyFormatted())
        - Net: \((totalIncome - totalSpent).currencyFormatted())
        \(budgetInfo)
        - Top spending categories: \(topCategories)

        You help users understand their spending, give financial insights, and suggest ways to save money.
        \(personality)
        When parsing voice input like "I spent $45 on groceries", confirm the transaction details before adding.
        """
    }

    // MARK: - Parse AI Transaction Intent

    func parseTransactionIntent(from text: String) async -> ParsedTransaction? {
        guard hasAPIKey else { return nil }
        guard let url = URL(string: "\(Constants.API.deepSeekBaseURL)/chat/completions") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Extract transaction details from: "\(text)"
        Respond ONLY with JSON: {"title": "...", "amount": 0.0, "isExpense": true}
        If no transaction detected, respond: null
        """

        let body: [String: Any] = [
            "model": Constants.API.deepSeekModel,
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

        return ParsedTransaction(title: parsed.title, amount: parsed.amount, isExpense: parsed.isExpense)
    }

    private struct ParsedTransactionDTO: Decodable {
        let title: String
        let amount: Double
        let isExpense: Bool
    }
}
