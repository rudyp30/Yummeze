import Foundation

/// A user's public identity, mirrored from the `profiles` table. This is the
/// cloud-backed replacement for the old local-only profile — display name and
/// avatar now live server-side so they read the same in every tab and, once
/// meals sync (Stage C), for every author. See [[multi-person-direction]].
///
/// The DB columns are snake_case; `CodingKeys` maps them to camelCase here.
/// `id` is the Supabase auth user id (the row's primary key).
struct Profile: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var username: String
    var displayName: String
    var avatarURL: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
    }

    /// First letter of the display name — for the fallback monogram avatar.
    var initial: String {
        String(displayName.first ?? "Y").uppercased()
    }
}
