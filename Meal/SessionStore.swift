import Foundation
import Observation

/// The single source of truth for "who is signed in and what should the app be
/// showing." Owns the auth phase, holds the current cloud profile, and is the
/// identity the feed / profile / settings read from. Auth and profile I/O are
/// delegated to swappable services so the backend can change without touching
/// the views. Meals stay local this stage — this only governs identity + gating.
@Observable
final class SessionStore {
    /// What the root should render. `.ready` carries the loaded profile so views
    /// can read identity straight off the phase.
    enum Phase: Equatable {
        case loading
        case signedOut
        case needsProfile
        case ready(Profile)
    }

    private(set) var phase: Phase = .loading

    private let auth: any AuthProviding
    private let profiles: ProfileService
    private var stateTask: Task<Void, Never>?

    init(auth: any AuthProviding = SupabaseAuthService(),
         profiles: ProfileService = ProfileService()) {
        self.auth = auth
        self.profiles = profiles
    }

    // MARK: - Identity (what the rest of the app reads)

    /// The current profile when the app is `.ready`, else nil.
    var currentProfile: Profile? {
        if case .ready(let profile) = phase { return profile }
        return nil
    }

    var displayName: String { currentProfile?.displayName ?? "You" }
    var username: String? { currentProfile?.username }
    var avatarURL: String? { currentProfile?.avatarURL }
    var initial: String { currentProfile?.initial ?? "Y" }

    // MARK: - Lifecycle

    /// Resolves the launch phase, then keeps it in sync with auth changes.
    /// Safe to call more than once; the observer is only wired up once.
    func start() async {
        await resolvePhase()
        guard stateTask == nil else { return }
        let stream = auth.authStateStream()
        stateTask = Task { [weak self] in
            for await _ in stream {
                await self?.resolvePhase()
            }
        }
    }

    /// Maps (has session?, has profile?) onto a phase. On a signed-in fetch
    /// failure we fall back to `.needsProfile` (with one retry first); if the
    /// user actually has a profile, `completeOnboarding` recovers it via the
    /// createProfile primary-key path rather than getting stuck.
    private func resolvePhase() async {
        guard auth.currentUserID != nil else {
            phase = .signedOut
            return
        }
        do {
            phase = try await fetchedPhase()
        } catch {
            try? await Task.sleep(for: .milliseconds(600))
            do { phase = try await fetchedPhase() }
            catch { phase = .needsProfile }
        }
    }

    private func fetchedPhase() async throws -> Phase {
        if let profile = try await profiles.fetchMyProfile() {
            return .ready(profile)
        }
        return .needsProfile
    }

    // MARK: - Auth actions (called by the screens)

    func sendCode(to email: String) async throws {
        try await auth.sendEmailCode(to: email)
    }

    func verifyCode(_ code: String, email: String) async throws {
        try await auth.verifyEmailCode(code, email: email)
        await resolvePhase()   // now signed in → .needsProfile or .ready
    }

    func signOut() async throws {
        try await auth.signOut()
        phase = .signedOut     // snappy; the auth-state observer confirms it too
    }

    /// The email the user signed in with — used to prefill the onboarding name.
    var signedInEmail: String? { auth.currentEmail }

    // MARK: - Profile actions

    func isUsernameAvailable(_ name: String) async throws -> Bool {
        try await profiles.isUsernameAvailable(name)
    }

    /// Uploads avatar bytes during onboarding (before a profile row exists) and
    /// returns the public URL to store with the new profile.
    func uploadAvatar(_ data: Data) async throws -> String {
        try await profiles.uploadAvatar(data)
    }

    func completeOnboarding(username: String, displayName: String, avatarURL: String?) async throws {
        let profile = try await profiles.createProfile(
            username: username,
            displayName: displayName,
            avatarURL: avatarURL
        )
        phase = .ready(profile)
    }

    func updateDisplayName(_ name: String) async throws {
        guard let current = currentProfile else { return }
        try await profiles.updateProfile(displayName: name, avatarURL: current.avatarURL)
        var updated = current
        updated.displayName = name
        phase = .ready(updated)
    }

    /// Uploads a new avatar and points the profile at it.
    func changeAvatar(_ data: Data) async throws {
        guard let current = currentProfile else { return }
        let url = try await profiles.uploadAvatar(data)
        try await profiles.updateProfile(displayName: current.displayName, avatarURL: url)
        var updated = current
        updated.avatarURL = url
        phase = .ready(updated)
    }

    func removeAvatar() async throws {
        guard let current = currentProfile, current.avatarURL != nil else { return }
        try await profiles.updateProfile(displayName: current.displayName, avatarURL: nil)
        var updated = current
        updated.avatarURL = nil
        phase = .ready(updated)
    }
}
