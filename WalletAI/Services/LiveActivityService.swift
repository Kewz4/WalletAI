import Foundation

final class LiveActivityService {
    static let shared = LiveActivityService()

    func startActivity(for transaction: Transaction) {}
    func endCurrentActivity() {}
}
