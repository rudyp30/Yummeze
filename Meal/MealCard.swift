import SwiftUI

/// One photo-forward feed card: author header, the photo, a like/comment row,
/// and the caption. All color comes from the current `Theme`.
struct MealCard: View {
    let meal: Meal

    @Environment(\.theme) private var theme
    @Environment(ProfileStore.self) private var profile
    @State private var liked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            photo
            reactions
            captionLine
        }
        .padding(12)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            avatarView
            VStack(alignment: .leading, spacing: 2) {
                Text(authorName)
                    .font(.headline)
                    .foregroundStyle(theme.base)
                Text(meal.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer(minLength: 8)
            typePill
        }
        // The whole post reads as one element; like/comment stay separate below.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(contentLabel)
    }

    private var avatarView: some View {
        ZStack {
            Circle().fill(theme.background)
            if isCurrentUser, let filename = profile.avatarFilename {
                LoadedImage(filename: filename, targetPoints: 36) { Color.clear }
            } else {
                Text(initial)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }

    private var typePill: some View {
        let color = theme.color(for: meal.mealType)
        return HStack(spacing: 5) {
            MealTypeIcon(type: meal.mealType, size: 15)
            Text(meal.mealType.displayName)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(color.readableText)
        .background(color, in: Capsule())
    }

    // MARK: Photo

    private var photo: some View {
        Color.clear
            .aspectRatio(1.0, contentMode: .fit)
            .overlay {
                let filenames = meal.photoFilenames
                if filenames.count > 1 {
                    // Swipeable carousel with page dots for multi-photo posts.
                    TabView {
                        ForEach(filenames, id: \.self) { name in
                            LoadedImage(filename: name, targetPoints: 430) { placeholder }
                        }
                    }
                    .tabViewStyle(.page)
                } else {
                    LoadedImage(filename: filenames.first, targetPoints: 430) { placeholder }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(photoLabel)
            .accessibilityAddTraits(.isImage)
    }

    private var placeholder: some View {
        let color = theme.color(for: meal.mealType)
        return ZStack {
            color.opacity(0.15)
            MealTypeIcon(type: meal.mealType, size: 48)
                .foregroundStyle(color.opacity(0.5))
        }
    }

    // MARK: Reactions

    private var reactions: some View {
        HStack(spacing: 12) {
            Button {
                liked.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(liked ? theme.color(for: .sweetTreat) : theme.secondaryText)
                    Text("\(liked ? 1 : 0)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Like")
            .accessibilityValue("\(liked ? 1 : 0) like\(liked ? "" : "s")")
            .accessibilityAddTraits(liked ? [.isButton, .isSelected] : .isButton)

            Button {
                // Comments arrive with the social layer.
            } label: {
                Image(systemName: "message")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comment")

            Spacer(minLength: 0)
        }
    }

    // MARK: Caption

    @ViewBuilder private var captionLine: some View {
        if !meal.caption.isEmpty {
            (Text(authorName).font(.subheadline.weight(.semibold))
             + Text(" ")
             + Text(meal.caption).font(.subheadline))
                .foregroundStyle(theme.base)
                .accessibilityHidden(true)   // folded into the card's combined label
        }
    }

    // MARK: Derived

    /// The current device user is "me" — resolve their name/photo from the local
    /// ProfileStore. Other authors (once the sync layer lands) fall back to their
    /// id for now; that's the seam a real profile lookup slots into later.
    private var isCurrentUser: Bool { meal.authorID == "me" }

    private var authorName: String {
        isCurrentUser ? profile.displayName : meal.authorID
    }

    private var initial: String {
        String(authorName.first ?? "Y").uppercased()
    }

    /// The whole post as one VoiceOver phrase: "{author}, {type}, {time}. {caption}".
    private var contentLabel: String {
        var label = "\(authorName), \(meal.mealType.displayName), "
            + meal.timestamp.formatted(date: .omitted, time: .shortened)
        if !meal.caption.isEmpty { label += ". \(meal.caption)" }
        return label
    }

    private var photoLabel: String {
        let base = meal.caption.isEmpty ? "\(meal.mealType.displayName) photo" : meal.caption
        let count = meal.photoFilenames.count
        return count > 1 ? "\(base), \(count) photos" : base
    }
}
