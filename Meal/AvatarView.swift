import SwiftUI

/// A circular avatar backed by a remote URL, falling back to a monogram on the
/// accent fill while loading, when there's no photo, or if the load fails. Used
/// everywhere an identity shows up (feed cards, profile, settings) so cloud
/// avatars render consistently. The photo is decorative here — callers label
/// the surrounding element for VoiceOver.
struct AvatarView: View {
    let urlString: String?
    let initial: String
    var diameter: CGFloat = 40

    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Circle().fill(theme.accent)
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        monogram
                    }
                }
            } else {
                monogram
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
    }

    private var monogram: some View {
        Text(initial)
            .font(.system(size: diameter * 0.42, weight: .semibold))
            .foregroundStyle(theme.onAccent)
            .minimumScaleFactor(0.5)
    }
}
