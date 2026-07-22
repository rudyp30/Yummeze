import SwiftUI

/// Renders a meal type's custom icon from Assets.xcassets/YummezeMealIcons.
/// The assets are template images, so the icon takes on the surrounding
/// `foregroundStyle` tint — same behavior the SF Symbols had.
struct MealTypeIcon: View {
    let type: MealType
    var size: CGFloat

    var body: some View {
        Image(type.icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
