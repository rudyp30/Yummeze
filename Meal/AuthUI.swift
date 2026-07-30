import SwiftUI

/// Shared building blocks for the auth + onboarding screens, so the welcome,
/// code-entry, and create-profile views share one look drawn from the theme.

/// The full-width sage action button (Continue / Verify). Shows a spinner while
/// working and dims when disabled; the tap target is a comfortable height.
struct AuthPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.headline)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView().tint(theme.onAccent)
                }
            }
            .foregroundStyle(theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 13))
            .opacity(isEnabled && !isLoading ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

/// The small uppercase field label ("EMAIL", "NAME", "USERNAME").
struct AuthFieldLabel: View {
    let text: String
    @Environment(\.theme) private var theme

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(theme.secondaryText)
    }
}

extension View {
    /// The white, rounded input container the auth text fields sit in.
    func authFieldBackground(_ theme: Theme) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 11))
    }
}

extension Theme {
    /// An accessible error/alert color: the dinner hue darkened enough to clear
    /// AA contrast for small text on the cream background.
    var errorText: Color { dinner.darkened(by: 0.32) }

    /// The faded placeholder/helper tone from the mockups.
    var faded: Color { secondaryText.opacity(0.55) }
}
