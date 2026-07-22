import Foundation
import SwiftData

/// The meal categories. `sweetTreat` gets to be first-class, as it should be.
/// Ordered the way they'll appear in the capture chips.
enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case sweetTreat
    case snack
    case drink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast:  "Breakfast"
        case .lunch:      "Lunch"
        case .dinner:     "Dinner"
        case .sweetTreat: "Sweet Treat"
        case .snack:      "Snack"
        case .drink:      "Drink"
        }
    }

    /// Custom icon asset name (Assets.xcassets/YummezeMealIcons), rendered as a
    /// template image so it takes on the surrounding tint. See `MealTypeIcon`.
    var icon: String {
        switch self {
        case .breakfast:  "MealBreakfast"
        case .lunch:      "MealLunch"
        case .dinner:     "MealDinner"
        case .sweetTreat: "MealSweetTreat"
        case .snack:      "MealSnack"
        case .drink:      "MealDrink"
        }
    }
}

@Model
final class Meal {
    var id: UUID
    /// Stored as the raw string and accessed through `mealType` below.
    /// This keeps the stored schema simple and predicate-friendly, and
    /// sidesteps SwiftData's occasional quirks with enum-typed properties.
    var mealTypeRaw: String
    var caption: String
    var timestamp: Date
    /// Legacy single-photo filename from before multi-photo. Kept so existing
    /// meals keep their image across the additive (lightweight) migration; new
    /// meals leave this nil and use `imageFilenames`. Read `photoFilenames`.
    var imageFilename: String?
    /// Ordered on-disk photo filenames — the source of truth for new meals
    /// (v2 multi-photo). Filenames, not image blobs, keep the store lean.
    var imageFilenames: [String] = []
    /// Unused in the local-only slice, but present now so the sync layer
    /// drops in later without a schema migration. "me" until there's a real identity.
    var authorID: String

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    /// Effective ordered photos: the multi-photo array, falling back to the
    /// legacy single filename for meals created before multi-photo.
    var photoFilenames: [String] {
        imageFilenames.isEmpty ? [imageFilename].compactMap { $0 } : imageFilenames
    }

    init(
        mealType: MealType,
        caption: String = "",
        timestamp: Date = .now,
        imageFilenames: [String] = [],
        authorID: String = "me"
    ) {
        self.id = UUID()
        self.mealTypeRaw = mealType.rawValue
        self.caption = caption
        self.timestamp = timestamp
        self.imageFilename = nil
        self.imageFilenames = imageFilenames
        self.authorID = authorID
    }
}
