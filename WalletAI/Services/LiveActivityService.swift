import Foundation

final class LiveActivityService {
    nonisolated(unsafe) static let shared = LiveActivityService()

    func startActivity(for transaction: Transaction) {}
    func endCurrentActivity() {}
}
