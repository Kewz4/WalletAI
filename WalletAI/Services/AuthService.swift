import Foundation
import AuthenticationServices
import UIKit
import SwiftUI

@MainActor
@Observable
final class AuthService: NSObject {
    static let shared = AuthService()

    var userName: String = UserDefaults.standard.string(forKey: "walletai_user_name") ?? ""
    var userEmail: String = UserDefaults.standard.string(forKey: "walletai_user_email") ?? ""
    var userID: String = UserDefaults.standard.string(forKey: "walletai_user_id") ?? ""
    var profileImage: UIImage? = nil
    var isSignedIn: Bool { !userID.isEmpty }
    var isLoading: Bool = false
    var error: String? = nil

    private override init() {
        super.init()
        if isSignedIn { loadProfilePhoto() }
    }

    func signInWithApple() {
        isLoading = true
        error = nil
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
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

    func loadProfilePhoto() {
        // CNContact Me card is not available on iOS; profile photo comes from Sign In with Apple
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let id = credential.user
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
        let email = credential.email ?? ""

        Task { @MainActor in
            self.userID = id
            if !name.isEmpty { self.userName = name }
            if !email.isEmpty { self.userEmail = email }
            UserDefaults.standard.set(id, forKey: "walletai_user_id")
            if !name.isEmpty { UserDefaults.standard.set(name, forKey: "walletai_user_name") }
            if !email.isEmpty { UserDefaults.standard.set(email, forKey: "walletai_user_email") }
            self.isLoading = false
            self.loadProfilePhoto()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            self.isLoading = false
            if (error as? ASAuthorizationError)?.code != .canceled {
                self.error = error.localizedDescription
            }
        }
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// SwiftUI wrapper
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
