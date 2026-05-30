import Foundation
import UIKit
import SwiftUI

// Simple local profile — SIWA requires a paid developer entitlement and won't work on sideloaded apps.
// Data stays on-device in UserDefaults; no authentication token is issued.

@MainActor
@Observable
final class AuthService: NSObject {
    static let shared = AuthService()

    var userName: String = UserDefaults.standard.string(forKey: "walletai_user_name") ?? ""
    var userEmail: String = UserDefaults.standard.string(forKey: "walletai_user_email") ?? ""
    var userID: String = UserDefaults.standard.string(forKey: "walletai_user_id") ?? ""
    var profileImage: UIImage? = nil

    var isSignedIn: Bool { !userID.isEmpty }

    private override init() { super.init() }

    func setProfile(name: String, email: String = "") {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        userName = n
        userEmail = email.trimmingCharacters(in: .whitespaces)
        if userID.isEmpty { userID = "local_\(UUID().uuidString)" }
        UserDefaults.standard.set(userName, forKey: "walletai_user_name")
        UserDefaults.standard.set(userEmail, forKey: "walletai_user_email")
        UserDefaults.standard.set(userID, forKey: "walletai_user_id")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func signOut() {
        userName = ""
        userEmail = ""
        userID = ""
        profileImage = nil
        UserDefaults.standard.removeObject(forKey: "walletai_user_name")
        UserDefaults.standard.removeObject(forKey: "walletai_user_email")
        UserDefaults.standard.removeObject(forKey: "walletai_user_id")
    }
}

// MARK: - SwiftUI profile image

struct ProfileImageView: View {
    let image: UIImage?
    let size: CGFloat
    var primaryColor: Color = .walletPrimary
    var accentColor: Color = .walletAccent

    var body: some View {
        if let img = image {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [primaryColor.opacity(0.8), accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: size, height: size)
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.44))
                    .foregroundStyle(.white)
            }
        }
    }
}
