import Foundation
import SwiftData

// MARK: - Actor-free helper (safe for AppIntent background context)

enum CategorizationHelper {
    private static let _key = ["gsk_1ZsUSfn2cD", "LJ93gbeFnOWGdyb3", "FYPtiV4EEpsG8kmd", "gUzqUCo8Ok"].joined()

    static func suggest(title: String, amount: Double, isExpense: Bool, existing: [String]) async -> String? {
        let apiKey = UserDefaults.standard.string(forKey: "walletai_groq_key") ?? _key
        let existingStr = existing.joined(separator: ", ")
        let prompt = """
        You are a financial categorization expert. Identify the most accurate category for this transaction.

        Transaction: "\(title)" — \(isExpense ? "expense" : "income") of \(String(format: "%.2f", amount))

        Think about what kind of business or service "\(title)" is:
        - Is it a restaurant, grocery store, gas station, subscription service, retailer, pharmacy, etc.?
        - Consider the amount: small amounts from coffee chains go to Coffee/Food, large amounts from electronics stores go to Electronics, etc.

        Existing categories (reuse one if it fits): \(existingStr.isEmpty ? "none yet" : existingStr)

        Reply with ONLY the category name — existing name exactly if it fits, or a concise new 1–2 word name. No explanation.
        """
        guard let url = URL(string: "https://api.groq.com/openai/v1/chat/completions") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "llama-3.3-70b-versatile",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 20
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

// MARK: - Main service (used in-app, runs on main actor)

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

        // Build name→category lookup
        var byName: [String: Category] = Dictionary(
            uniqueKeysWithValues: categories.map { ($0.name.lowercased(), $0) }
        )

        // Build merchant→category history from already-categorized transactions.
        // The AI will use these as training examples for consistency.
        var merchantHistory: [String: String] = [:]
        for tx in transactions {
            if let catName = tx.category?.name {
                let key = tx.title.lowercased().trimmingCharacters(in: .whitespaces)
                if merchantHistory[key] == nil {
                    merchantHistory[key] = catName
                }
            }
        }

        var categorized = 0
        var newCatsCreated = 0
        let batchSize = 12
        let batches = stride(from: 0, to: transactions.count, by: batchSize).map {
            Array(transactions[$0..<min($0 + batchSize, transactions.count)])
        }

        for (bi, batch) in batches.enumerated() {
            let lo = bi * batchSize + 1
            let hi = min((bi + 1) * batchSize, transactions.count)
            statusMessage = "Analyzing \(lo)–\(hi) of \(transactions.count)…"

            let prompt = buildBatchPrompt(
                batch: batch,
                byName: byName,
                merchantHistory: merchantHistory
            )

            if let items = await callGroq(prompt: prompt) {
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

                    // Update merchant history so later batches learn from this
                    let merchantKey = tx.title.lowercased().trimmingCharacters(in: .whitespaces)
                    if merchantHistory[merchantKey] == nil {
                        merchantHistory[merchantKey] = item.cat
                    }
                    categorized += 1
                }
            }

            progress = Double(bi + 1) / Double(batches.count)
        }

        try? context.save()

        let suffix = newCatsCreated > 0
            ? " · \(newCatsCreated) new \(newCatsCreated == 1 ? "category" : "categories") created"
            : ""
        completionMessage = "\(categorized) of \(transactions.count) transactions organized\(suffix)"
        statusMessage = ""
        isRunning = false
        progress = 0
    }

    // MARK: - Prompt builder

    private func buildBatchPrompt(
        batch: [Transaction],
        byName: [String: Category],
        merchantHistory: [String: String]
    ) -> String {
        let existingList = byName.keys.map { $0.capitalized }.sorted().joined(separator: ", ")

        // Show up to 20 past categorizations as few-shot examples
        let examples = merchantHistory.prefix(20).map { "\"\($0.key)\" → \($0.value)" }.joined(separator: "\n")

        let txLines = batch.enumerated().map { i, tx in
            "\(i). \"\(tx.title)\"  \(tx.isExpense ? "-" : "+")\(String(format: "%.2f", tx.amount))"
        }.joined(separator: "\n")

        return """
        You are an expert financial analyst who deeply knows brands, merchants, and spending patterns.

        Your job: categorize each transaction as accurately as possible.

        For every merchant/title, reason through:
        1. What kind of business is this? (e.g. "Uber Eats" = food delivery, "Planet Fitness" = gym, "Netflix" = streaming)
        2. Does the amount match typical spending for that business type?
        3. Have we seen this merchant before? Use the history below for consistency.

        ── Past categorizations (learn from these) ──
        \(examples.isEmpty ? "(none yet)" : examples)

        ── Available categories (reuse exactly when they fit) ──
        \(existingList.isEmpty ? "none yet — create appropriate ones" : existingList)

        ── Transactions to categorize ──
        \(txLines)

        ── Output format ──
        Reply with ONLY a compact JSON array. No markdown, no explanation:
        [{"i":0,"cat":"Food","emoji":"🍕","new":false},{"i":1,"cat":"Transport","emoji":"🚗","new":false}]

        Rules:
        - "cat" must exactly match an existing category name (case-insensitive) when reusing one
        - Set "new":true only for genuinely distinct types not covered by existing categories
        - New category names: title case, 1–2 words maximum
        - Every transaction index must appear exactly once
        - Income transactions (+ prefix) should use categories like "Salary", "Freelance", "Refund", etc.
        """
    }

    // MARK: - Helpers

    private struct BatchItem: Decodable { let i: Int; let cat: String; let emoji: String; let new: Bool }

    private func callGroq(prompt: String) async -> [BatchItem]? {
        guard let url = URL(string: "\(Constants.API.groqBaseURL)/chat/completions") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": Constants.API.groqModel,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 1000
        ])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let content = (choices.first?["message"] as? [String: Any])?["content"] as? String,
              let bracketStr = extractBrackets(from: content),
              let items = try? JSONDecoder().decode([BatchItem].self, from: Data(bracketStr.utf8))
        else { return nil }
        return items
    }

    private func extractBrackets(from text: String) -> String? {
        guard let s = text.firstIndex(of: "["), let e = text.lastIndex(of: "]") else { return nil }
        return String(text[s...e])
    }
}
