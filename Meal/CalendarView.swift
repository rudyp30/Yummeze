import SwiftUI
import SwiftData

/// The archive: a month grid across all of history, from every author (unlike
/// the feed, which is bounded to today + yesterday). Tapping a day lists that
/// day's meals below the grid, chronologically. Colors come from the theme.
struct CalendarView: View {
    @Environment(\.theme) private var theme

    @State private var visibleMonth: Date
    @State private var selectedDay: Date?

    init() {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        _visibleMonth = State(initialValue: monthStart)
        _selectedDay = State(initialValue: calendar.startOfDay(for: .now))
    }

    var body: some View {
        // Grid + detail scroll together as one — nothing has to fit on a single
        // screen, so growing the grid never squishes the detail.
        ScrollView {
            VStack(spacing: 0) {
                monthNav
                weekdayHeader
                // Re-created when the month changes → fresh month-bounded @Query.
                MonthContent(month: visibleMonth, selectedDay: $selectedDay)
                    .id(visibleMonth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    // MARK: Month nav

    private var monthNav: some View {
        HStack(spacing: 16) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Previous month")
            Text(monthLabel)
                .font(.headline)
                .foregroundStyle(theme.base)
                .frame(minWidth: 130)
                .accessibilityAddTraits(.isHeader)
            Button { step(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Next month")
        }
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(theme.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<weekdaySymbols.count, id: \.self) { i in
                Text(weekdaySymbols[i])
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    // MARK: Derived

    private var monthLabel: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    /// Single-letter weekday symbols rotated to the locale's first weekday.
    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func step(_ delta: Int) {
        let calendar = Calendar.current
        guard let shifted = calendar.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        visibleMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: shifted)) ?? shifted
        selectedDay = nil   // changing months clears the selection
    }

}

// MARK: - One month

/// Owns the query for a single month's meals (bounded predicate) and renders
/// both the grid dots and the selected-day detail from one in-memory grouping.
private struct MonthContent: View {
    @Environment(\.theme) private var theme
    let month: Date
    @Binding var selectedDay: Date?
    @Query private var meals: [Meal]

    init(month: Date, selectedDay: Binding<Date?>) {
        self.month = month
        self._selectedDay = selectedDay
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        _meals = Query(
            filter: #Predicate<Meal> { $0.timestamp >= monthStart && $0.timestamp < nextMonth },
            sort: \Meal.timestamp,
            order: .forward   // ascending → the day's story reads morning → night
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            grid
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            Rectangle()
                .fill(theme.secondaryText.opacity(0.15))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
            detail
        }
    }

    // MARK: Grid

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(gridDays) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        let calendar = Calendar.current
        let isToday = day.inMonth && calendar.isDateInToday(day.date)
        let isSelected = day.inMonth && (selectedDay.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false)
        let number = calendar.component(.day, from: day.date)
        let cats = day.inMonth ? categories(on: day.date) : []

        return VStack(spacing: 2) {
            Text("\(number)")
                .font(.system(size: 13, weight: isToday ? .bold : .medium))
                .foregroundStyle(numberColor(day: day, isToday: isToday))
            dotsRow(cats)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.9, contentMode: .fit)
        .background {
            if isSelected {
                // Fills the (near-square) cell minus a small inset — a bigger,
                // contained rounded square, not a stretched oval. Size knob:
                // lower the .padding to enlarge the box, raise it to shrink.
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.accent.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.accent, lineWidth: 1))
                    .padding(-2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if day.inMonth { selectedDay = day.date }
        }
        // Meals are shown as colored dots — meaningless to VoiceOver/colorblind
        // users — so fold the whole cell into one spoken label instead.
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(!day.inMonth)
        .accessibilityLabel(dayLabel(day, isToday: isToday, cats: cats))
        .accessibilityAddTraits(day.inMonth ? (isSelected ? [.isButton, .isSelected] : .isButton) : [])
    }

    private func dayLabel(_ day: CalendarDay, isToday: Bool, cats: [MealType]) -> String {
        guard day.inMonth else { return "" }
        let dateStr = day.date.formatted(.dateTime.month(.wide).day())   // "July 5"
        var label = isToday ? "Today, \(dateStr)" : dateStr
        if cats.isEmpty {
            label += ", no meals"
        } else {
            let count = meals(on: day.date).count
            let names = cats.map { $0.displayName.lowercased() }.joined(separator: ", ")
            label += ", \(count) meal\(count == 1 ? "" : "s"): \(names)"
        }
        return label
    }

    private func numberColor(day: CalendarDay, isToday: Bool) -> Color {
        if !day.inMonth { return theme.secondaryText.opacity(0.4) }
        if isToday { return theme.accent }
        return theme.base
    }

    /// Fixed-height dots row so day numbers stay aligned whether or not the day
    /// has meals. Up to 3 distinct-category dots, then a "+".
    private func dotsRow(_ cats: [MealType]) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(cats.prefix(3)), id: \.self) { cat in
                let dot = theme.color(for: cat)
                Circle()
                    .fill(dot)
                    .overlay(Circle().strokeBorder(dot.darkened(by: 0.3), lineWidth: 0.5))
                    .frame(width: 6, height: 6)
            }
            if cats.count > 3 {
                Text("+")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .frame(height: 8)
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        if let selectedDay {
            VStack(alignment: .leading, spacing: 16) {
                Text(detailHeader(selectedDay))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityAddTraits(.isHeader)

                let dayMeals = self.meals(on: selectedDay)
                if dayMeals.isEmpty {
                    Text("No Yummeze logged this day.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                } else {
                    ForEach(dayMeals) { meal in
                        MealCard(meal: meal)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 24)
        } else {
            Text("Pick a day to see its Yummeze.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 36)
        }
    }

    // MARK: Data

    private var mealsByDay: [Date: [Meal]] {
        Dictionary(grouping: meals) { Calendar.current.startOfDay(for: $0.timestamp) }
    }

    private func meals(on day: Date) -> [Meal] {
        mealsByDay[day] ?? []
    }

    /// Distinct categories logged that day, in `MealType` enum order.
    private func categories(on day: Date) -> [MealType] {
        let present = Set(meals(on: day).map(\.mealType))
        return MealType.allCases.filter { present.contains($0) }
    }

    private func detailHeader(_ day: Date) -> String {
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: .now)
        let formatter = DateFormatter()
        formatter.dateFormat = sameYear ? "EEE, MMM d" : "EEE, MMM d, yyyy"
        return formatter.string(from: day)
    }

    // MARK: Grid math

    private struct CalendarDay: Identifiable {
        let date: Date
        let inMonth: Bool
        var id: Date { date }
    }

    /// Leading previous-month fillers + this month's days + trailing fillers to
    /// complete the final week (5–6 rows), respecting the locale's first weekday.
    private var gridDays: [CalendarDay] {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) ?? monthStart
        let totalCells = Int((Double(leading + daysInMonth) / 7.0).rounded(.up)) * 7
        return (0..<totalCells).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: gridStart) ?? gridStart
            let inMonth = calendar.isDate(date, equalTo: monthStart, toGranularity: .month)
            return CalendarDay(date: calendar.startOfDay(for: date), inMonth: inMonth)
        }
    }
}
