import Foundation

/// Time spent keeping the Mac awake, stored as seconds per calendar day.
final class Stats {
    private static let storageKey = "secondsByDay"
    private static let daysKept = 35

    private let defaults: UserDefaults
    private var calendar: Calendar { .current }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Adds the time between two dates. A stretch that crosses midnight is
    /// split so each day gets its own share.
    func add(from start: Date, to end: Date) {
        guard start < end else { return }

        var days = secondsByDay
        var cursor = start
        while cursor < end {
            let nextDay = calendar.dateInterval(of: .day, for: cursor)?.end ?? end
            let sliceEnd = min(nextDay, end)
            days[dayKey(for: cursor), default: 0] += sliceEnd.timeIntervalSince(cursor)
            cursor = sliceEnd
        }

        let cutoff = calendar.date(byAdding: .day, value: -Self.daysKept, to: end) ?? end
        let oldestKept = dayKey(for: cutoff)
        secondsByDay = days.filter { $0.key >= oldestKept }
    }

    func today(now: Date = Date()) -> TimeInterval {
        secondsByDay[dayKey(for: now)] ?? 0
    }

    /// The week starts on the first weekday of the user's calendar.
    func thisWeek(now: Date = Date()) -> TimeInterval {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return today(now: now)
        }
        let days = dayKey(for: week.start)...dayKey(for: now)
        return secondsByDay.filter { days.contains($0.key) }.values.reduce(0, +)
    }

    /// "1 h 12 m", or "35 m" under an hour.
    static func format(minutes: Int) -> String {
        let (hours, minutes) = minutes.quotientAndRemainder(dividingBy: 60)
        if hours == 0 { return "\(minutes) m" }
        if minutes == 0 { return "\(hours) h" }
        return "\(hours) h \(minutes) m"
    }

    private var secondsByDay: [String: Double] {
        get { defaults.dictionary(forKey: Self.storageKey) as? [String: Double] ?? [:] }
        set { defaults.set(newValue, forKey: Self.storageKey) }
    }

    /// Zero padded, so the keys sort in date order.
    private func dayKey(for date: Date) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }
}
