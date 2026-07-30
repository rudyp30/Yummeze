import Foundation
import Supabase

/// What the app needs from an authentication backend. Everything above this
/// protocol (SessionStore and the screens) depends only on it — so Sign in with
/// Apple can be added later as another `AuthProviding` implementation (or extra
/// methods here) with no downstream changes.
protocol AuthProviding {
    /// The signed-in user's id, or nil if there's no session.
    var currentUserID: UUID? { get }

    /// Emails a one-time code to `email`, creating the user if they're new.
    func sendEmailCode(to email: String) async throws

    /// Verifies the emailed code, establishing (and persisting) a session.
    func verifyEmailCode(_ code: String, email: String) async throws

    /// Clears the session.
    func signOut() async throws

    /// The signed-in user's email, when available (used to prefill onboarding).
    var currentEmail: String? { get }

    /// Emits `true`/`false` (signed in / out) whenever the session state changes,
    /// including the initial state at launch. Token refreshes are filtered out.
    func authStateStream() -> AsyncStream<Bool>
}

/// Supabase email-OTP implementation. Sessions persist across launches via the
/// SDK's Keychain-backed storage, so a returning user is already signed in.
struct SupabaseAuthService: AuthProviding {
    private var auth: AuthClient { SupabaseManager.shared.auth }

    var currentUserID: UUID? { auth.currentUser?.id }
    var currentEmail: String? { auth.currentUser?.email }

    func sendEmailCode(to email: String) async throws {
        // Deliberately NO `redirectTo` — and the client sets no default
        // `redirectToURL` — because a redirect is exactly what turns the email
        // into a magic *link*. With none, `signInWithOTP` sends no `redirect_to`
        // and Supabase emails the OTP token (rendered by the `{{ .Token }}`
        // template). This is native iOS with no web redirect target, so keep this
        // link-free to stay code-based. Do not add a `redirectTo` here.
        try await auth.signInWithOTP(email: email, shouldCreateUser: true)
    }

    func verifyEmailCode(_ code: String, email: String) async throws {
        // Exchanges the 6 digits the user typed for a session. `.email` is the
        // OTP type for the numeric code from `signInWithOTP` (not `.magiclink`,
        // which verifies a tapped link's token). Throws on a wrong/expired code.
        _ = try await auth.verifyOTP(email: email, token: code, type: .email)
    }

    func signOut() async throws {
        try await auth.signOut()
    }

    func authStateStream() -> AsyncStream<Bool> {
        let changes = auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await (event, session) in changes {
                    switch event {
                    case .signedIn, .signedOut, .initialSession, .userDeleted:
                        continuation.yield(session != nil)
                    default:
                        // tokenRefreshed / userUpdated / etc. — no sign-in/out change.
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
