import SwiftUI

/// The app shell: a wordmark bar on top, the selected tab in the middle, and a
/// custom bottom bar with an elevated center Add button that opens the capture
/// sheet. Built custom (not a system TabView) so the Add button can sit raised.
struct RootTabView: View {
    @Environment(\.theme) private var theme
    @State private var tab: Tab = .feed
    @State private var showingCapture = false

    enum Tab { case feed, calendar, profile }

    var body: some View {
        VStack(spacing: 0) {
            // Profile provides its own wordmark+gear bar inside a NavigationStack.
            if tab != .profile { topBar }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
        .background(theme.background)
        .sheet(isPresented: $showingCapture) {
            MealCaptureView()
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .feed:
            MealFeedView(selectedTab: $tab)
        case .calendar:
            CalendarView()
        case .profile:
            ProfileView()
        }
    }

    // MARK: Top bar

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
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(theme.card)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.secondaryText.opacity(0.15))
                .frame(height: 0.5)
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(.feed, icon: "rectangle.grid.1x2", label: "Feed", iconSize: 20)
            tabButton(.calendar, icon: "calendar", label: "Calendar")
            addButton
            tabButton(.profile, icon: "person", label: "Profile")
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(theme.card)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.secondaryText.opacity(0.15))
                .frame(height: 0.5)
        }
    }

    private func tabButton(_ target: Tab, icon: String, label: String, iconSize: CGFloat = 22) -> some View {
        let selected = tab == target
        return Button {
            tab = target
        } label: {
            VStack(spacing: 5) {
                tabIcon(icon, selected: selected, size: iconSize)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(selected ? theme.accentText : theme.secondaryText)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// Fill-on-select: SF Symbols switch to their `.fill` variant when active.
    /// `calendar` has no fill variant, so it swaps to the custom filled asset.
    @ViewBuilder
    private func tabIcon(_ icon: String, selected: Bool, size: CGFloat) -> some View {
        if icon == "calendar", selected {
            // Pin the filled calendar to the SF `calendar` glyph's exact
            // footprint (invisible reference) so selecting it never changes
            // size relative to the unselected SF calendar.
            Image(systemName: "calendar")
                .font(.system(size: size, weight: .semibold))
                .hidden()
                .overlay {
                    Image("CalendarFill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                }
        } else {
            Image(systemName: icon)
                .symbolVariant(selected ? .fill : .none)
                .font(.system(size: size, weight: .semibold))
        }
    }

    private var addButton: some View {
        Button {
            showingCapture = true
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(theme.onAccent)
                    )
                    .frame(height: 18, alignment: .bottom)
                Text("Add")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add meal")
        .accessibilityAddTraits(.isButton)
    }
}

