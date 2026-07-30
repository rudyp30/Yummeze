import SwiftUI
import SwiftData

/// Profile tab. Wrapped in a NavigationStack so the gear can push Settings.
struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ProfileHome()
        }
    }
}

private struct ProfileHome: View {
    @Environment(\.theme) private var theme
    @Environment(SessionStore.self) private var session
    @Query private var meals: [Meal]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 16) {
                    header
                    statsCard
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Top bar (wordmark + gear → Settings)

    private var topBar: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.accent.opacity(0.15))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "fork.knife")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accent)
                )
            Text("Yummeze")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.base)
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(theme.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.secondaryText.opacity(0.15)).frame(height: 0.5)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            avatar
            Text(session.displayName)
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.base)
            if let since = sinceText {
                Text("logging Yummeze since \(since)")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.top, 8)
    }

    private var avatar: some View {
        AvatarView(urlString: session.avatarURL, initial: session.initial, diameter: 76)
            .accessibilityHidden(true)   // the display name is read as text below
    }

    private var sinceText: String? {
        guard let earliest = meals.map(\.timestamp).min() else { return nil }
        return earliest.formatted(.dateTime.month(.abbreviated).year())
    }

    // MARK: Stats

    private var statsCard: some View {
        let counts = categoryCounts
        let maxCount = counts.values.max() ?? 0
        return VStack(spacing: 14) {
            VStack(spacing: 3) {
                Text("\(meals.count)")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(theme.base)
                Text("Yummeze logged")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            .accessibilityElement(children: .combine)

            if meals.isEmpty {
                Text("Log your first Yummeze to see your stats")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
            } else {
                Rectangle().fill(theme.secondaryText.opacity(0.12)).frame(height: 0.5)
                VStack(alignment: .leading, spacing: 11) {
                    Text("By category")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(theme.secondaryText)
                    ForEach(MealType.allCases) { type in
                        categoryRow(type, count: counts[type] ?? 0, maxCount: maxCount)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func categoryRow(_ type: MealType, count: Int, maxCount: Int) -> some View {
        let color = theme.color(for: type)
        let fraction = maxCount > 0 ? Double(count) / Double(maxCount) : 0
        return HStack(spacing: 8) {
            MealTypeIcon(type: type, size: 16)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(type.displayName)
                .font(.footnote)
                .foregroundStyle(theme.base)
                .frame(width: 74, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.secondaryText.opacity(0.12))
                    Capsule().fill(color).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 8)
            Text("\(count)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.base)
                .frame(width: 24, alignment: .trailing)
        }
        // Bar length isn't the only signal — read as "Lunch, 32".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(type.displayName), \(count)")
    }

    private var categoryCounts: [MealType: Int] {
        Dictionary(grouping: meals, by: { $0.mealType }).mapValues(\.count)
    }
}
