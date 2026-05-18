//
//  StreakStore.swift
//  Bestie-Check
//
//  Duolingo-style daily streak + streak freeze (offline, UserDefaults).
//

import Foundation
import Combine

// MARK: - Models

struct StreakPersistedState: Codable {
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var freezeCount: Int = 0
    /// yyyy-MM-dd of last successful check-in
    var lastCheckInDayKey: String?
    /// Recent check-in days for calendar UI (newest last)
    var checkedInDayKeys: [String] = []
}

enum StreakCheckInOutcome: Equatable {
    case alreadyCheckedInToday
    case checkedIn(
        streak: Int,
        freezeEarned: Int,
        freezeUsed: Bool,
        isFirstEver: Bool
    )
}

// MARK: - Month grid models

struct StreakMonthDay: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let dayNumber: Int
    let inCurrentMonth: Bool
    let isToday: Bool
    let isFuture: Bool
    let checkedIn: Bool
}

struct StreakMonthGrid: Equatable {
    let title: String
    let days: [StreakMonthDay]
}

// MARK: - Store

@MainActor
final class StreakStore: ObservableObject {
    static let shared = StreakStore()

    private static let storageKey = "bestie_check.streak_state"
    private static let calendar = Calendar.current

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var freezeCount: Int = 0
    @Published private(set) var checkedInToday: Bool = false
    /// Set when a new check-in happens; UI can show celebration then clear.
    @Published var latestCheckInOutcome: StreakCheckInOutcome?

    private var lastCheckInDayKey: String?
    private var checkedInDayKeys: [String] = []

    private init() {
        load()
        refreshCheckedInToday()
    }

    // MARK: - Check-in (call after first successful face scan of the day)

    @discardableResult
    func recordCheckInAfterFaceScan(date: Date = Date()) -> StreakCheckInOutcome {
        let todayKey = Self.dayKey(for: date)
        refreshCheckedInToday(for: date)

        if lastCheckInDayKey == todayKey {
            let outcome: StreakCheckInOutcome = .alreadyCheckedInToday
            return outcome
        }

        let previousStreak = currentStreak
        var freezeUsed = false

        if let lastKey = lastCheckInDayKey,
           let lastDate = Self.date(fromDayKey: lastKey),
           let todayStart = Self.startOfDay(for: date) {
            let lastStart = Self.startOfDay(for: lastDate) ?? lastDate
            let gap = Self.calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0

            switch gap {
            case 1:
                currentStreak = max(1, previousStreak + 1)
            case 2:
                if freezeCount > 0 {
                    freezeCount -= 1
                    freezeUsed = true
                    currentStreak = max(1, previousStreak + 1)
                } else {
                    currentStreak = 1
                }
            default:
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        lastCheckInDayKey = todayKey
        appendCheckedInDay(todayKey)

        var freezeEarned = 0
        if currentStreak > 0, currentStreak % 7 == 0 {
            freezeCount += 1
            freezeEarned = 1
        }

        checkedInToday = true
        persist()

        let isFirstEver = previousStreak == 0 && checkedInDayKeys.count == 1
        let outcome: StreakCheckInOutcome = .checkedIn(
            streak: currentStreak,
            freezeEarned: freezeEarned,
            freezeUsed: freezeUsed,
            isFirstEver: isFirstEver
        )
        latestCheckInOutcome = outcome
        return outcome
    }

    func clearLatestCheckInOutcome() {
        latestCheckInOutcome = nil
    }

    /// Last 7 calendar days (oldest → newest) with whether user checked in.
    func weekCheckInStatus(endingOn date: Date = Date()) -> [(date: Date, checkedIn: Bool)] {
        guard let end = Self.startOfDay(for: date) else { return [] }
        let keys = Set(checkedInDayKeys)
        return (0..<7).compactMap { offset -> (Date, Bool)? in
            guard let day = Self.calendar.date(byAdding: .day, value: offset - 6, to: end) else { return nil }
            let key = Self.dayKey(for: day)
            return (day, keys.contains(key))
        }
    }

    /// Days remaining until the next freeze reward (current streak modulo 7).
    var progressToNextFreeze: (current: Int, total: Int) {
        (currentStreak % 7, 7)
    }

    /// Build a Monday-leading month grid for the calendar view.
    /// Pads with previous/next month days so the grid is a full multiple of 7.
    func monthGrid(containing date: Date = Date()) -> StreakMonthGrid {
        var cal = Self.calendar
        cal.firstWeekday = 2 // Monday
        let today = cal.startOfDay(for: Date())
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let monthStart = cal.date(from: comps),
              let monthRange = cal.range(of: .day, in: .month, for: monthStart) else {
            return StreakMonthGrid(title: "", days: [])
        }

        // Title like "May 2026"
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL yyyy"
        let title = formatter.string(from: monthStart)

        // Monday-based leading offset: weekday is 1..7 with firstWeekday=2,
        // so we compute (weekday - firstWeekday + 7) % 7.
        let firstWeekday = cal.component(.weekday, from: monthStart)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7

        let keys = Set(checkedInDayKeys)
        var cells: [StreakMonthDay] = []

        // Leading: previous-month padding
        for i in stride(from: leading, to: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: monthStart) {
                cells.append(makeDay(d, inMonth: false, today: today, keys: keys, cal: cal))
            }
        }
        // Current month days
        for day in monthRange {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(makeDay(d, inMonth: true, today: today, keys: keys, cal: cal))
            }
        }
        // Trailing: next-month padding to fill the last week
        let remainder = cells.count % 7
        if remainder != 0 {
            let needed = 7 - remainder
            if let last = cells.last?.date {
                for i in 1...needed {
                    if let d = cal.date(byAdding: .day, value: i, to: last) {
                        cells.append(makeDay(d, inMonth: false, today: today, keys: keys, cal: cal))
                    }
                }
            }
        }

        return StreakMonthGrid(title: title, days: cells)
    }

    private func makeDay(
        _ date: Date,
        inMonth: Bool,
        today: Date,
        keys: Set<String>,
        cal: Calendar
    ) -> StreakMonthDay {
        let dayStart = cal.startOfDay(for: date)
        let key = Self.dayKey(for: date)
        return StreakMonthDay(
            date: dayStart,
            dayNumber: cal.component(.day, from: date),
            inCurrentMonth: inMonth,
            isToday: dayStart == today,
            isFuture: dayStart > today,
            checkedIn: keys.contains(key)
        )
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let state = try? JSONDecoder().decode(StreakPersistedState.self, from: data) else {
            return
        }
        currentStreak = state.currentStreak
        longestStreak = state.longestStreak
        freezeCount = state.freezeCount
        lastCheckInDayKey = state.lastCheckInDayKey
        checkedInDayKeys = state.checkedInDayKeys
    }

    private func persist() {
        let state = StreakPersistedState(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            freezeCount: freezeCount,
            lastCheckInDayKey: lastCheckInDayKey,
            checkedInDayKeys: checkedInDayKeys
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func refreshCheckedInToday(for date: Date = Date()) {
        let todayKey = Self.dayKey(for: date)
        checkedInToday = lastCheckInDayKey == todayKey
    }

    private func appendCheckedInDay(_ key: String) {
        checkedInDayKeys.removeAll { $0 == key }
        checkedInDayKeys.append(key)
        if checkedInDayKeys.count > 120 {
            checkedInDayKeys.removeFirst(checkedInDayKeys.count - 120)
        }
    }

    // MARK: - Debug helpers (DEBUG builds only)

    #if DEBUG
    /// Force a check-in for `today + daysFromNow`. Wraps the production logic
    /// so the streak / freeze rules behave exactly the same.
    @discardableResult
    func debugCheckIn(daysFromNow: Int) -> StreakCheckInOutcome {
        let target = Self.calendar.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        return recordCheckInAfterFaceScan(date: target)
    }

    /// Wipe all streak state (UserDefaults + in-memory). Useful for debugging.
    func debugResetAll() {
        currentStreak = 0
        longestStreak = 0
        freezeCount = 0
        lastCheckInDayKey = nil
        checkedInDayKeys = []
        checkedInToday = false
        latestCheckInOutcome = nil
        persist()
    }

    /// Read-only snapshot for debug UI.
    var debugSnapshot: (current: Int, longest: Int, freezes: Int, lastKey: String?) {
        (currentStreak, longestStreak, freezeCount, lastCheckInDayKey)
    }
    #endif

    // MARK: - Date helpers

    private static func dayKey(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]
        c.month = parts[1]
        c.day = parts[2]
        return calendar.date(from: c)
    }

    private static func startOfDay(for date: Date) -> Date? {
        calendar.startOfDay(for: date)
    }
}
