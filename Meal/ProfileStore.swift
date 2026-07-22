import SwiftUI

/// Local, single-user profile (display name + avatar). Centralized here so the
/// eventual accounts migration has ONE place to change — views never read the
/// UserDefaults keys directly. The avatar image lives in `ImageStore`; only its
/// filename is persisted. See [[multi-person-direction]] for the bigger picture.
@Observable
final class ProfileStore {
    private enum Keys {
        static let displayName = "displayName"
        static let avatarFilename = "avatarFilename"
    }

    private(set) var displayName: String
    private(set) var avatarFilename: String?

    init() {
        let defaults = UserDefaults.standard
        displayName = defaults.string(forKey: Keys.displayName) ?? "You"
        avatarFilename = defaults.string(forKey: Keys.avatarFilename)
    }

    func setDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Keys.displayName)
    }

    /// Replaces the avatar image, deleting the previous file. Pass nil to clear.
    func setAvatar(filename: String?) {
        if let old = avatarFilename, old != filename {
            ImageStore.delete(old)
        }
        avatarFilename = filename
        UserDefaults.standard.set(filename, forKey: Keys.avatarFilename)
    }

    /// First letter of the display name — for the fallback monogram avatar.
    var initial: String {
        String(displayName.first ?? "Y").uppercased()
    }
}
