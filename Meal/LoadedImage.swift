import SwiftUI

/// Loads a meal photo through `ImageStore` off the main thread, sized for the
/// space it's given, and shows a themed placeholder until it arrives. This is
/// what keeps the feed from decoding full-resolution photos while scrolling.
struct LoadedImage<Placeholder: View>: View {
    let filename: String?
    /// Longest edge in points; converted to pixels via the display scale.
    var targetPoints: CGFloat
    @ViewBuilder var placeholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        content
            .task(id: filename) {
                image = nil
                image = await ImageStore.image(
                    named: filename,
                    maxPixelSize: targetPoints * displayScale
                )
            }
    }

    @ViewBuilder private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholder()
        }
    }
}
