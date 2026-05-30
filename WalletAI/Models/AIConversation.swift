import Foundation
import SwiftData

@Model
final class AIConversation {
    var id: UUID
    var messages: [AIMessage]
    var createdAt: Date
    var title: String

    init(id: UUID = UUID(), title: String = "New Conversation") {
        self.id = id
        self.messages = []
        self.createdAt = Date()
        self.title = title
    }
}

struct AIChartData: Codable {
    enum ChartType: String, Codable { case bar, pie }
    let type: ChartType
    let labels: [String]
    let values: [Double]
    var title: String?
    var currency: String?
}

struct AIMessage: Codable, Identifiable {
    var id: UUID
    var role: Role
    var content: String
    var timestamp: Date
    var isStreaming: Bool
    var chartPayload: AIChartData?

    enum Role: String, Codable {
        case user, assistant, system
    }

    init(id: UUID = UUID(), role: Role, content: String, isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isStreaming = isStreaming
        self.chartPayload = nil
    }
}
