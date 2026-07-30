import Foundation
import Supabase

/// Things that can go wrong talking to the `profiles` table, surfaced in a form
/// the UI can act on.
enum ProfileError: LocalizedError {
    case notAuthenticated
    case usernameTaken

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "You're not signed in."
        case .usernameTaken:    "That username was just taken — try another."
        }
    }
}

/// All reads and writes for the current user's cloud profile, plus avatar
/// uploads. Every method runs against the shared Supabase client; RLS on the
/// server is what actually scopes writes to the signed-in user.
struct ProfileService {
    private var client: SupabaseClient { SupabaseManager.shared }
    private var table: String { "profiles" }
    private var avatarBucket: String { "avatars" }

    private var currentUserID: UUID? {
        client.auth.currentUser?.id
    }

    // MARK: - Reads

    /// The signed-in user's profile row, or nil if they haven't created one yet.
    /// Returns nil (not an error) for "no row" so callers can route to onboarding.
    func fetchMyProfile() async throws -> Profile? {
        guard let uid = currentUserID else { return nil }
        let rows: [Profile] = try await client
            .from(table)
            .select()
            .eq("id", value: uid.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Whether `name` is free to claim. Case-insensitive: usernames are stored
    /// lowercase, so we compare lowercased. Available == no row already has it.
    func isUsernameAvailable(_ name: String) async throws -> Bool {
        // Decode into a minimal row so this doesn't depend on being able to read
        // every profile column of another user.
        struct Row: Decodable { let id: UUID }
        let rows: [Row] = try await client
            .from(table)
            .select("id")
            .eq("username", value: name.lowercased())
            .limit(1)
            .execute()
            .value
        return rows.isEmpty
    }

    // MARK: - Writes

    /// Inserts the current user's profile row (id == their auth user id) and
    /// returns the created row (with the server-assigned `created_at`).
    ///
    /// A unique-violation (23505) is ambiguous — it's either a username clash or
    /// this user already has a row (primary key). We disambiguate by re-fetching:
    /// if a row for this user now exists, that's their profile (recover it);
    /// otherwise the username was taken.
    func createProfile(username: String, displayName: String, avatarURL: String?) async throws -> Profile {
        guard let uid = currentUserID else { throw ProfileError.notAuthenticated }

        struct Insert: Encodable {
            let id: String
            let username: String
            let displayName: String
            let avatarURL: String?
            enum CodingKeys: String, CodingKey {
                case id, username
                case displayName = "display_name"
                case avatarURL = "avatar_url"
            }
        }
        let payload = Insert(
            id: uid.uuidString,
            username: username.lowercased(),
            displayName: displayName,
            avatarURL: avatarURL
        )

        do {
            let created: Profile = try await client
                .from(table)
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            return created
        } catch let error as PostgrestError where error.code == "23505" {
            if let existing = try? await fetchMyProfile() { return existing }
            throw ProfileError.usernameTaken
        }
    }

    /// Updates the mutable identity fields. Both are written every call (passing
    /// nil for `avatarURL` clears the photo), so callers pass the current value
    /// for whichever field they aren't changing.
    func updateProfile(displayName: String, avatarURL: String?) async throws {
        guard let uid = currentUserID else { throw ProfileError.notAuthenticated }

        // Encode avatar_url explicitly (not encodeIfPresent) so nil becomes SQL
        // NULL and actually clears the column, rather than being omitted.
        struct Update: Encodable {
            let displayName: String
            let avatarURL: String?
            enum CodingKeys: String, CodingKey {
                case displayName = "display_name"
                case avatarURL = "avatar_url"
            }
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(displayName, forKey: .displayName)
                try c.encode(avatarURL, forKey: .avatarURL)
            }
        }

        try await client
            .from(table)
            .update(Update(displayName: displayName, avatarURL: avatarURL))
            .eq("id", value: uid.uuidString)
            .execute()
    }

    // MARK: - Avatar upload

    /// Uploads avatar bytes and returns a public URL to display.
    ///
    /// The object path MUST begin with the user's id as the first folder — the
    /// Storage RLS policies key off that first path segment, so any other shape
    /// is rejected. We upsert to a fixed name so a user has at most one avatar
    /// object; a cache-busting `?v=` is appended to the returned URL so the fixed
    /// path doesn't serve a stale image after a change.
    func uploadAvatar(_ data: Data) async throws -> String {
        guard let uid = currentUserID else { throw ProfileError.notAuthenticated }
        let path = "\(uid.uuidString)/avatar.jpg"

        _ = try await client.storage
            .from(avatarBucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))

        let publicURL = try client.storage.from(avatarBucket).getPublicURL(path: path)
        var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)
        let version = String(Int(Date().timeIntervalSince1970))
        components?.queryItems = [URLQueryItem(name: "v", value: version)]
        return (components?.url ?? publicURL).absoluteString
    }
}
