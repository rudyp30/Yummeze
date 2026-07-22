import SwiftUI

// MARK: - Hex + contrast helpers

extension Color {
    /// Build a Color from a "#RRGGBB" string.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// WCAG relative luminance (0…1).
    private var relativeLuminance: Double {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> Double {
            let c = Double(c)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// WCAG contrast ratio (1…21) between this color and another.
    private func contrastRatio(to other: Color) -> Double {
        let a = relativeLuminance, b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// The single canonical "ink on a colored fill" helper: whichever of the dark
    /// ink or white has the higher *WCAG* contrast on this fill (not perceptual
    /// luma, which mis-picked white on mid-tone category colors). Used at every
    /// colored-fill text site — meal-type pills, capture chips.
    var readableText: Color {
        let darkInk = Color(hex: "#231A12")
        return contrastRatio(to: darkInk) >= contrastRatio(to: .white) ? darkInk : .white
    }

    /// A darker shade of the same hue (reduced HSB brightness) — outlines a
    /// low-contrast dot against cream without changing its hue.
    func darkened(by amount: Double) -> Color {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(b) * (1 - amount), opacity: Double(a))
    }
}

// MARK: - Theme

/// A complete palette. The whole app draws its colors from the *current* theme
/// rather than from system semantic colors — that's what lets us offer a
/// picker (light / dark / two named themes) instead of just following iOS.
struct Theme: Identifiable {
    let id: String
    let name: String          // shown in the future theme picker

    // Core
    let base: Color           // primary ink / text
    let background: Color     // app background
    let card: Color           // feed card surface
    let secondaryText: Color
    let accent: Color         // fills: Add button, selection fills, logo tile
    let onAccent: Color       // text/icons sitting on the accent fill
    let accentText: Color     // darker sage for accent-colored TEXT on light bg

    // Meal categories
    let breakfast: Color
    let lunch: Color
    let dinner: Color
    let sweetTreat: Color
    let snack: Color
    let drink: Color

    func color(for type: MealType) -> Color {
        switch type {
        case .breakfast:  breakfast
        case .lunch:      lunch
        case .dinner:     dinner
        case .sweetTreat: sweetTreat
        case .snack:      snack
        case .drink:      drink
        }
    }
}

extension Theme: Equatable, Hashable {
    static func == (lhs: Theme, rhs: Theme) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - The palettes

extension Theme {
    /// The locked v1 palette.
    static let cozyCream = Theme(
        id: "cozyCream",
        name: "Cozy Cream",
        base:          Color(hex: "#3A2E28"),
        background:    Color(hex: "#FBF6EF"),
        card:          Color(hex: "#FFFFFF"),
        secondaryText: Color(hex: "#7C6F65"),   // AA-normal on cream (4.52:1)
        accent:        Color(hex: "#829B69"),   // Sage (fill)
        onAccent:      Color(hex: "#FFFFFF"),
        accentText:    Color(hex: "#5F7548"),   // darker sage, AA-normal text on cream (4.74:1)
        breakfast:     Color(hex: "#F4B400"),
        lunch:         Color(hex: "#34A853"),
        dinner:        Color(hex: "#E4572E"),
        sweetTreat:    Color(hex: "#E86A92"),
        snack:         Color(hex: "#9B7EDE"),
        drink:         Color(hex: "#4CA6C9")
    )

    // Coming later — each just needs its palette filled in, no code changes:
    //   static let dusk = Theme(id: "dusk", name: "Dusk", ...)          // dark mode
    //   static let <you>   = Theme(id: "...", name: "...", ...)          // named for you
    //   static let <friend> = Theme(id: "...", name: "...", ...)         // named for your friend

    /// Every selectable theme. Add new palettes here and the picker updates itself.
    static let all: [Theme] = [.cozyCream]

    static func byID(_ id: String) -> Theme {
        all.first { $0.id == id } ?? .cozyCream
    }
}

// MARK: - Environment access

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .cozyCream
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
