import Foundation
import Supabase

enum AuthenticationPhase: Equatable {
    case checking
    case unauthenticated
    case onboarding
    case authenticated
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var phase: AuthenticationPhase = .checking
    @Published private(set) var session: Session?
    @Published private(set) var configurationMessage: String?

    let client: SupabaseClient?
    private var observerTask: Task<Void, Never>?

    init() {
        do {
            let client = try SupabaseClientProvider.makeClient()
            self.client = client
            observeAuthState(client: client)
        } catch {
            client = nil
            configurationMessage = error.localizedDescription
            phase = .unauthenticated
        }
    }

    deinit {
        observerTask?.cancel()
    }

    var isConfigured: Bool {
        client != nil
    }

    var currentUserLabel: String {
        session?.user.email ?? session?.user.phone ?? "Authenticated user"
    }

    func handleOpenURL(_ url: URL) {
        client?.auth.handle(url)
    }

    func sendPhoneOTP(to phone: String) async -> AuthActionResult {
        guard let client else { return .failure(configurationMessage ?? "Supabase is not configured.") }
        do {
            try await client.auth.signInWithOTP(phone: phone)
            return .success("We sent a 6-digit code to \(phone).")
        } catch {
            return .failure(Self.friendlyMessage(for: error, fallback: "Unable to send that SMS code."))
        }
    }

    func resendPhoneOTP(to phone: String) async -> AuthActionResult {
        guard let client else { return .failure(configurationMessage ?? "Supabase is not configured.") }

        do {
            try await client.auth.resend(phone: phone, type: .sms)
            return .success("A fresh code is on the way.")
        } catch {
            return .failure(Self.friendlyMessage(for: error, fallback: "Unable to resend the code."))
        }
    }

    func verifyPhoneOTP(phone: String, code: String) async -> AuthActionResult {
        guard let client else { return .failure(configurationMessage ?? "Supabase is not configured.") }

        do {
            try await client.auth.verifyOTP(phone: phone, token: code, type: .sms)
            return .success(nil)
        } catch {
            return .failure(Self.friendlyMessage(for: error, fallback: "That code could not be verified."))
        }
    }

    func signUpWithEmail(email: String, password: String) async -> AuthActionResult {
        guard let client else { return .failure(configurationMessage ?? "Supabase is not configured.") }

        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                redirectTo: SupabaseClientProvider.redirectURL
            )

            if response.session == nil {
                return .success("Check your email to confirm the account, then log in.")
            }

            return .success(nil)
        } catch {
            return .failure(Self.friendlyMessage(for: error, fallback: "Unable to create that account."))
        }
    }

    func signInWithEmail(email: String, password: String) async -> AuthActionResult {
        guard let client else { return .failure(configurationMessage ?? "Supabase is not configured.") }

        do {
            try await client.auth.signIn(email: email, password: password)
            return .success(nil)
        } catch {
            return .failure(Self.friendlyMessage(for: error, fallback: "Unable to sign in with those credentials."))
        }
    }

    func signOut() async -> AuthActionResult {
        guard let client else {
            applySession(nil)
            return .success(nil)
        }

        do {
            try await client.auth.signOut()
            applySession(nil)
            return .success(nil)
        } catch {
            return .failure(Self.friendlyMessage(for: error, fallback: "Unable to log out."))
        }
    }

    func completeOnboarding(preferredPeptideName: String) {
        guard let userID = session?.user.id.uuidString else { return }
        UserDefaults.standard.set(true, forKey: onboardingKey(for: userID))
        UserDefaults.standard.set(preferredPeptideName, forKey: "preferredPeptideName")
        phase = .authenticated
    }

    private func observeAuthState(client: SupabaseClient) {
        observerTask = Task { [weak self] in
            for await (event, session) in client.auth.authStateChanges {
                await MainActor.run {
                    self?.applySession(session, event: event)
                }
            }
        }
    }

    private func applySession(_ session: Session?, event: AuthChangeEvent? = nil) {
        self.session = session

        guard let session else {
            phase = .unauthenticated
            return
        }

        if event == .initialSession && session.isExpired {
            phase = .checking
            return
        }

        let userID = session.user.id.uuidString
        phase = UserDefaults.standard.bool(forKey: onboardingKey(for: userID)) ? .authenticated : .onboarding
    }

    private func onboardingKey(for userID: String) -> String {
        "onboardingCompleted.\(userID)"
    }

    private static func friendlyMessage(for error: Error, fallback: String) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "Network connection lost. Check your connection and try again."
            case .timedOut:
                return "The network request timed out. Try again in a moment."
            default:
                return "Network error. Please try again."
            }
        }

        if let authError = error as? AuthError {
            switch authError.errorCode {
            case .invalidCredentials:
                return "No account matched that email/password combination."
            case .userNotFound:
                return "No account was found for that email."
            case .emailExists, .userAlreadyExists:
                return "An account with that email already exists. Log in instead."
            case .otpExpired:
                return "That code expired. Request a new one and try again."
            case .validationFailed:
                return "That code is invalid. Check the digits and try again."
            case .overRequestRateLimit, .overSMSSendRateLimit, .overEmailSendRateLimit:
                return "Too many attempts. Please wait a moment before trying again."
            case .emailNotConfirmed:
                return "Confirm your email address before logging in."
            case .phoneProviderDisabled:
                return "Phone login is not enabled for this Supabase project."
            case .emailProviderDisabled:
                return "Email login is not enabled for this Supabase project."
            case .weakPassword:
                return "Choose a stronger password with at least 8 characters."
            default:
                let message = authError.message.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercasedMessage = message.lowercased()

                if lowercasedMessage.contains("invalid") && (lowercasedMessage.contains("otp") || lowercasedMessage.contains("token") || lowercasedMessage.contains("code")) {
                    return "That code is invalid. Check the digits and try again."
                }

                if lowercasedMessage.contains("expired") && (lowercasedMessage.contains("otp") || lowercasedMessage.contains("token") || lowercasedMessage.contains("code")) {
                    return "That code expired. Request a new one and try again."
                }

                return message.isEmpty ? fallback : message
            }
        }

        return fallback
    }
}

enum AuthActionResult: Equatable {
    case success(String?)
    case failure(String)

    var message: String? {
        switch self {
        case let .success(message): message
        case let .failure(message): message
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
