import SwiftUI
import SwiftData

@main
struct YummezeApp: App {
    /// Remembers which theme the user picked. Defaults to Cozy Cream.
    /// When the picker ships, this is the only thing it needs to change.
    @AppStorage("selectedThemeID") private var selectedThemeID = Theme.cozyCream.id
    @State private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.theme, Theme.byID(selectedThemeID))
                .environment(session)
        }
        .modelContainer(for: Meal.self)
    }
}
