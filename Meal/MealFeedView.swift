import SwiftUI
import SwiftData

struct MealFeedView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @Binding var selectedTab: RootTabView.Tab
    @Query private var meals: [Meal]

    /// The feed is bounded to the present — today and yesterday only. Anything
    /// older lives in the calendar (the archive). The cutoff (start of
    /// yesterday) is computed once here and baked into the query predicate.
    init(selectedTab: Binding<RootTabView.Tab>) {
        self._selectedTab = selectedTab
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) ?? .now
        let cutoff = calendar.startOfDay(for: yesterday)
        _meals = Query(
            filter: #Predicate<Meal> { $0.timestamp >= cutoff },
            sort: \Meal.timestamp,
            order: .reverse
        )
    }

    var body: some View {
        Group {
            if meals.isEmpty {
                emptyState
            } else {
                feed
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    // MARK: Feed

    private var feed: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(days) { section in
                    Section {
                        ForEach(section.meals) { meal in
                            MealCard(meal: meal)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        delete(meal)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        sectionHeader(for: section.day)
                    }
                }
                calendarCap
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
    }

    /// One day's worth of the bounded feed.
    private struct DaySection: Identifiable {
        let day: Date
        let meals: [Meal]
        var id: Date { day }
    }

    /// Groups the already-sorted query into days (newest first) in a single
    /// pass — no re-sorting. Within-day order is preserved from the query.
    private var days: [DaySection] {
        let grouped = Dictionary(grouping: meals) { Calendar.current.startOfDay(for: $0.timestamp) }
        return grouped.keys.sorted(by: >).map { DaySection(day: $0, meals: grouped[$0] ?? []) }
    }

    private func sectionHeader(for day: Date) -> some View {
        Text(headerTitle(for: day))
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .background(theme.background)
            .accessibilityAddTraits(.isHeader)
    }

    private func headerTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted) // shouldn't occur given the filter
    }

    /// A gentle signpost at the end of the feed toward the archive.
    private var calendarCap: some View {
        Button {
            selectedTab = .calendar
        } label: {
            Text("Look at past Yummeze in the calendar!")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.accentText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the Calendar tab")
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.largeTitle)
                .foregroundStyle(theme.secondaryText)
            Text("No meals today or yesterday")
                .font(.headline)
                .foregroundStyle(theme.base)
            Text("Tap the button below to log one.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(_ meal: Meal) {
        ImageStore.delete(meal.photoFilenames)
        context.delete(meal)
    }
}
