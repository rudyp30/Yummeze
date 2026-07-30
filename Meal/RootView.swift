import SwiftUI

/// The very top of the view tree: it shows the right screen for the current
/// auth phase and kicks off session resolution at launch. Everything else
/// (the tab shell, the auth flow) hangs off one of these branches.
struct RootView: View {
    @Environment(\.theme) private var theme
    @Environment(SessionStore.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch session.phase {
            case .loading:
                ZStack {
                    theme.background.ignoresSafeArea()
                    ProgressView().tint(theme.accent)
                }
            case .signedOut:
                WelcomeView()
            case .needsProfile:
                OnboardingView()
            case .ready:
                RootTabView()
            }
        }
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: session.phase)
        .task { await session.start() }
    }
}
