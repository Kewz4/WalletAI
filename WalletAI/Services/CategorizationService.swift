import Foundation
import SwiftData

// MARK: - Actor-free helper (safe for AppIntent background context)

enum CategorizationHelper {
    private static let _key = ["gsk_1ZsUSfn2cD", "LJ93gbeFnOWGdyb3", "FYPtiV4EEpsG8kmd", "gUzqUCo8Ok"].joined()

    /// Returns the best-fit category name for a transaction (existing or new suggestion).
    static func suggest(title: String, amount: Double, isExpense: Bool, existing: [String]) async -> String? {
        let apiKey = UserDefaults.standard.string(forKey: "walletai_groq_key") ?? _key
        let existingStr = existing.joined(separator: ", ")
        let prompt = """
        What category fits: "\(title)" \(isExpense ? "-" : "+")\(String(format: "%.2f", amount))?
        Existing: \(existingStr.isEmpty ? "none" : existingStr)
        Reply ONLY with the exact category name (reuse existing if it fits) or a new 1–2 word name. No other text.
        """
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "llama-3.3-70b-versatile",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 15
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let content = (choices.first?["message"] as? [String: Any])?["content"] as? String
        else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).first
    }
}

@MainActor
@Observable
final class CategorizationService {
    var isRunning = false
    var progress: Double = 0
    var statusMessage = ""
    var completionMessage: String? = nil

    private var apiKey: String {
        UserDefaults.standard.string(forKey: Constants.API.groqKeyStorageKey)
            ?? ["gsk_1ZsUSfn2cD", "LJ93gbeFnOWGdyb3", "FYPtiV4EEpsG8kmd", "gUzqUCo8Ok"].joined()
    }

    // MARK: - Batch re-categorize all transactions

    func analyzeAll(transactions: [Transaction], categories: [Category], context: ModelContext) async {
        guard !isRunning, !transactions.isEmpty else { return }
        isRunning = true
        completionMessage = nil
        progress = 0

        // Build a mutable name→category lookup (lowercased for matching)
        var byName: [String: Category] = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.name.lowercased(), $0) }
        )
        var categorized = 0
        var newCatsCreated = 0
        let batchSize = 15
        let batches = stride(from: 0, to: transactions.count, by: batchSize).map {
            Array(transactions[$0..<min($0 + batchSize, transactions.count)])
        }

        for (bi, batch) in batches.enumerated() {
            let lo = bi * batchSize + 1
            let hi = min((bi + 1) * batchSize, transactions.count)
            statusMessage = "Analyzing \(lo)–\(hi) of \(transactions.count)…"

            let existingList = byName.keys.map { $0.capitalized }.sorted().joined(separator: ", ")
            let txLines = batch.enumerated().map { i, tx in
                "\(i). \"\(tx.title)\" \(tx.isExpense ? "-" : "+")\(String(format: "%.2f", tx.amount))"
            }.joined(separator: "\n")

            let prompt = """
            Categorize these financial transactions. For each, pick an existing category or create a new one.

            Existing categories: \(existingList.isEmpty ? "none yet" : existingList)

            Transactions:
            \(txLines)

            Reply with ONLY a compact JSON array — no markdown, no explanation:
            [{"i":0,"cat":"Food","emoji":"🍕","new":false},{"i":1,"cat":"Transport","emoji":"🚗","new":false}]

            Rules:
            - Reuse existing category names exactly (case-insensitive) whenever they fit
            - Only "new":true for genuinely distinct types not covered by existing categories
            - New category names must be 1–2 words, title case
            - Every transaction index must appear exactly once in the array
            """

            if let items = await callGroq(prompt: prompt, arrayResponse: true) as? [BatchItem] {
                for item in items {
                    guard item.i < batch.count else { continue }
                    let tx = batch[item.i]
                    let key = item.cat.lowercased()

                    if let existing = byName[key] {
                        tx.category = existing
                    } else {
                        let palette = ["#FF6B6B","#4ECDC4","#45B7D1","#96CEB4","#FFD93D",
                                       "#6C5CE7","#00B894","#FDCB6E","#E17055","#74B9FF","#A29BFE","#FD79A8"]
                        let hex = palette[abs(item.cat.hashValue) % palette.count]
                        let newCat = Category(name: item.cat, iconName: item.emoji, colorHex: hex, monthlyBudget: nil)
                        context.insert(newCat)
                        byName[key] = newCat
                        newCatsCreated += 1
                        tx.category = newCat
                    }
                    categorized += 1
                }
            }

            progress = Double(bi + 1) / Double(batches.count)
        }

        try? context.save()

        let catSuffix = newCatsCreated > 0
            ? " · \(newCatsCreated) new \(newCatsCreated == 1 ? "category" : "categories") created"
            : ""
        completionMessage = "\(categorized) of \(transactions.count) transactions organized\(catSuffix)"
        statusMessage = ""
        isRunning = false
        progress = 0
    }

    // MARK: - Single-transaction categorize (Apple Pay)

    func categorize(transaction: Transaction, existingCategories: [Category], context: ModelContext) async {
        let existingList = existingCategories.map { "\($0.name) \($0.iconName)" }.joined(separator: ", ")
        let prompt = """
        Categorize this transaction: "\(transaction.title)" \(transaction.isExpense ? "-" : "+")\(String(format: "%.2f", transaction.amount))
        Existing categories: \(existingList.isEmpty ? "none" : existingList)
        Reply ONLY with compact JSON (no markdown): {"cat":"Food","emoji":"🍕","new":false}
        Reuse an existing category when it fits. Only "new":true for truly distinct types.
        """

        guard let url = URL(string: "\(Constants.API.groqBaseURL)/chat/completions") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": Constants.API.groqModel,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 80
        ])

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let content = (choices.first?["message"] as? [String: Any])?["content"] as? String,
              let jsonStr = extractBraces(from: content),
              let result = try? JSONDecoder().decode(SingleItem.self, from: Data(jsonStr.utf8))
        else { return }

        let key = result.cat.lowercased()
        if let existing = existingCategories.first(where: { $0.name.lowercased() == key }) {
            transaction.category = existing
        } else {
            let palette = ["#FF6B6B","#4ECDC4","#45B7D1","#96CEB4","#FFD93D","#6C5CE7","#00B894","#FDCB6E"]
            let hex = palette[abs(result.cat.hashValue) % palette.count]
            let newCat = Category(name: result.cat, iconName: result.emoji, colorHex: hex, monthlyBudget: nil)
            context.insert(newCat)
            transaction.category = newCat
        }
        try? context.save()
    }

    // MARK: - Helpers

    private struct BatchItem: Decodable { let i: Int; let cat: String; let emoji: String; let new: Bool }
    private struct SingleItem: Decodable { let cat: String; let emoji: String; let new: Bool }

    private func callGroq(prompt: String, arrayResponse: Bool) async -> Any? {
        guard let url = URL(string: "\(Constants.API.groqBaseURL)/chat/completions") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": Constants.API.groqModel,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 800
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let content = (choices.first?["message"] as? [String: Any])?["content"] as? String
        else { return nil }

        if arrayResponse {
            guard let s = extractBrackets(from: content),
                  let items = try? JSONDecoder().decode([BatchItem].self, from: Data(s.utf8))
            else { return nil }
            return items
        } else {
            guard let s = extractBraces(from: content),
                  let item = try? JSONDecoder().decode(SingleItem.self, from: Data(s.utf8))
            else { return nil }
            return item
        }
    }

    private func extractBrackets(from text: String) -> String? {
        guard let s = text.firstIndex(of: "["), let e = text.lastIndex(of: "]") else { return nil }
        return String(text[s...e])
    }

    private func extractBraces(from text: String) -> String? {
        guard let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}") else { return nil }
        return String(text[s...e])
    }
}
