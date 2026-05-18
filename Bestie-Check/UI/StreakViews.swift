//
//  StreakViews.swift
//  Bestie-Check
//

import SwiftUI

// MARK: - Flame badge (main screen)

struct StreakFlameBadge: View {
    @ObservedObject var store: StreakStore
    var onTap: () -> Void

    private var flameActive: Bool { store.currentStreak > 0 || store.checkedInToday }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(flameGradient)
                    .symbolEffect(.pulse, options: .repeating, isActive: store.checkedInToday && store.currentStreak > 0)

                Text("\(store.currentStreak)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                if store.freezeCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "snowflake")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(store.freezeCount)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.cyan.opacity(0.95))
                    .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.45))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Streak \(store.currentStreak), \(store.freezeCount) freezes")
    }

    private var flameGradient: LinearGradient {
        if flameActive {
            return LinearGradient(
                colors: [Color.orange, Color(red: 1, green: 0.35, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.35)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Streak palette

private enum StreakPalette {
    static let signed = Color(red: 95 / 255, green: 125 / 255, blue: 235 / 255)   // #5F7DEB
    static let missed = Color(red: 207 / 255, green: 6 / 255, blue: 85 / 255)     // #CF0655
    static let empty  = Color(red: 248 / 255, green: 248 / 255, blue: 248 / 255)  // #F8F8F8
    static let today  = Color(red: 90 / 255, green: 200 / 255, blue: 110 / 255)   // green
    static let cardBg = Color.white.opacity(0.92)
    static let textPrimary   = Color(red: 0.06, green: 0.10, blue: 0.22)
    static let textSecondary = Color(red: 0.06, green: 0.10, blue: 0.22).opacity(0.55)
    static let textMuted     = Color(red: 0.06, green: 0.10, blue: 0.22).opacity(0.30)
}

// MARK: - Detail sheet

struct StreakDetailSheet: View {
    @ObservedObject var store: StreakStore
    @Environment(\.dismiss) private var dismiss

    private let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    heroSection
                    monthSection
                    legendSection
                    freezeSection
                    howItWorksSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .scrollContentBackground(.hidden)
            .background(Color.white.opacity(0.82).ignoresSafeArea())
            .navigationTitle("Daily Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.white.opacity(0.82), for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StreakPalette.textPrimary)
                }
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .preferredColorScheme(.light)
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, Color(red: 1, green: 0.3, blue: 0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .orange.opacity(0.35), radius: 12)

            Text("\(store.currentStreak)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(StreakPalette.textPrimary)

            Text(store.checkedInToday ? "Checked in today!" : "Complete a face scan to check in")
                .font(.subheadline)
                .foregroundStyle(StreakPalette.textSecondary)
                .multilineTextAlignment(.center)

            if store.longestStreak > 0 {
                Text("Longest streak: \(store.longestStreak) days")
                    .font(.caption)
                    .foregroundStyle(StreakPalette.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: Month calendar

    private var monthSection: some View {
        let grid = store.monthGrid()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

        return VStack(alignment: .leading, spacing: 14) {
            Text(grid.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(StreakPalette.textPrimary)

            // Weekday header
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { idx, sym in
                    VStack(spacing: 4) {
                        Text(sym)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(idx == 0 ? StreakPalette.signed : StreakPalette.textSecondary)
                        if idx == 0 {
                            Rectangle()
                                .fill(StreakPalette.signed)
                                .frame(height: 2)
                                .frame(width: 28)
                        } else {
                            Color.clear.frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(grid.days) { day in
                    MonthDayCell(day: day)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(StreakPalette.cardBg)
                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
        )
    }

    // MARK: Legend

    private var legendSection: some View {
        HStack(spacing: 22) {
            legendDot(color: StreakPalette.signed, label: "Signed in")
            legendDot(color: StreakPalette.missed, label: "Not checked in")
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 14, height: 14)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(StreakPalette.textSecondary)
        }
    }

    // MARK: Freeze

    private var freezeSection: some View {
        let (current, total) = store.progressToNextFreeze
        let remaining = total - current
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: "snowflake")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.cyan)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Streak Freeze")
                        .font(.headline)
                        .foregroundStyle(StreakPalette.textPrimary)
                    Text("Covers one missed day so your streak continues.")
                        .font(.caption)
                        .foregroundStyle(StreakPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text("×\(store.freezeCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.cyan))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Next freeze")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StreakPalette.textSecondary)
                    Spacer()
                    Text(remaining == 0 || remaining == total
                         ? "Earn 1 by streaking 7 days"
                         : "in \(remaining) day\(remaining == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(StreakPalette.textSecondary)
                }
                GeometryReader { geo in
                    let frac = total > 0 ? CGFloat(current) / CGFloat(total) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.cyan.opacity(0.18))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.cyan, Color(red: 0.2, green: 0.55, blue: 0.95)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geo.size.width * frac))
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.cyan.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: How it works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it works")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StreakPalette.textSecondary)

            bullet("Check in automatically after your first face scan each day.")
            bullet("Keep your streak by scanning at least once every day.")
            bullet("Miss one day? A Streak Freeze is used automatically if you have one.")
            bullet("Earn 1 Streak Freeze for every 7-day streak.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(StreakPalette.cardBg)
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
        )
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(StreakPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Month day cell

private struct MonthDayCell: View {
    let day: StreakMonthDay

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fillColor)

            if day.isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(StreakPalette.today, lineWidth: 2)
            }

            Text("\(day.dayNumber)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var isInactive: Bool {
        !day.inCurrentMonth || day.isFuture
    }

    private var fillColor: Color {
        if isInactive { return StreakPalette.empty }
        if day.isToday && !day.checkedIn { return Color.white }
        if day.checkedIn { return StreakPalette.signed }
        return StreakPalette.missed
    }

    private var textColor: Color {
        if isInactive { return StreakPalette.textMuted }
        if day.isToday && !day.checkedIn { return StreakPalette.textPrimary }
        return .white
    }
}

// MARK: - Check-in celebration overlay

struct StreakCheckInCelebration: View {
    let outcome: StreakCheckInOutcome
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        if case .checkedIn(let streak, let freezeEarned, let freezeUsed, _) = outcome {
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: 16) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, Color(red: 1, green: 0.25, blue: 0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)

                    Text("\(streak) Day Streak!")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Checked in for today")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))

                    if freezeEarned > 0 {
                        Label("+\(freezeEarned) Streak Freeze", systemImage: "snowflake")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.cyan)
                            .padding(.top, 4)
                    }

                    if freezeUsed {
                        Label("Streak Freeze used", systemImage: "snowflake")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.cyan.opacity(0.85))
                    }

                    Button("Nice!", action: dismiss)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(.white))
                        .padding(.top, 8)
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(white: 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 36)
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)
            }
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    appeared = true
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

#Preview("Badge") {
    ZStack {
        Color.black.ignoresSafeArea()
        StreakFlameBadge(store: StreakStore.shared) {}
    }
}
