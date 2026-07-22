import UIKit
import ImageIO

/// Photos live as files in the app's Documents directory; the model only
/// stores the filename. Saving downscales to a ~1080px master, and loading
/// decodes straight to display size off the main thread with an in-memory
/// cache — so the feed stays smooth no matter how many meals pile up.
enum ImageStore {
    /// Longest-edge cap for the on-disk master. Ample for a phone-width card,
    /// and keeps the multi-megapixel original from ever hitting disk.
    private static let masterMaxDimension: CGFloat = 1080

    /// Decoded thumbnails, keyed by "filename@pixelSize". NSCache is thread-safe
    /// and evicts under memory pressure on its own.
    private static let cache = NSCache<NSString, UIImage>()

    private static var directory: URL {
        let dir = URL.documentsDirectory.appending(path: "MealImages")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Save

    /// Downscales to a master image and writes it as JPEG. Returns the filename
    /// to store on the `Meal`, or nil if encoding failed.
    static func save(_ image: UIImage) -> String? {
        let master = downscaled(image, maxDimension: masterMaxDimension)
        guard let data = master.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: directory.appending(path: filename))
            return filename
        } catch {
            print("ImageStore save failed: \(error)")
            return nil
        }
    }

    // MARK: - Load

    /// Decodes the image at (about) `maxPixelSize` pixels on its longest edge,
    /// off the main thread, and caches the result. Pass points × displayScale.
    static func image(named filename: String?, maxPixelSize: CGFloat) async -> UIImage? {
        guard let filename, maxPixelSize > 0 else { return nil }
        let key = "\(filename)@\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let url = directory.appending(path: filename)
        let decoded = await Task.detached(priority: .userInitiated) {
            downsample(at: url, maxPixelSize: maxPixelSize)
        }.value

        if let decoded { cache.setObject(decoded, forKey: key) }
        return decoded
    }

    // MARK: - Delete

    static func delete(_ filename: String?) {
        guard let filename else { return }
        try? FileManager.default.removeItem(at: directory.appending(path: filename))
    }

    /// Deletes every file in the list — used when a multi-photo meal is removed.
    static func delete(_ filenames: [String]) {
        for filename in filenames { delete(filename) }
    }

    // MARK: - Helpers

    /// ImageIO downsampling: decodes directly to a thumbnail of the requested
    /// max pixel size without ever fully decoding the original into memory.
    nonisolated private static func downsample(at url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Aspect-preserving downscale for the on-disk master. Returns the original
    /// untouched if it's already within bounds.
    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
