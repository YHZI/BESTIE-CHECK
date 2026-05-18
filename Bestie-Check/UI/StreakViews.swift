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

// MARK: - Detail sheet

struct StreakDetailSheet: View {
    @ObservedObject var store: StreakStore
    @Environment(\.dismiss) private var dismiss

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection
                    weekSection
                    freezeSection
                    howItWorksSection
                }
                .padding(24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Daily Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

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
                .shadow(color: .orange.opacity(0.5), radius: 12)

            Text("\(store.currentStreak)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(store.checkedInToday ? "Checked in today!" : "Complete a face scan to check in")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)

            if store.longestStreak > 0 {
                Text("Longest streak: \(store.longestStreak) days")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 0) {
                ForEach(Array(store.weekCheckInStatus().enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 8) {
                        Text(weekdaySymbols[Calendar.current.component(.weekday, from: item.date) - 1])
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))

                        ZStack {
                            Circle()
                                .fill(item.checkedIn ? Color.orange : Color.white.opacity(0.1))
                                .frame(width: 32, height: 32)

                            if item.checkedIn {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
    }

    private var freezeSection: some View {
        HStack(spacing: 14) {
            Image(systemName: "snowflake")
                .font(.system(size: 28))
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text("Streak Freeze ×\(store.freezeCount)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Covers one missed day so your streak continues.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cyan.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.cyan.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it works")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))

            bullet("Check in automatically after your first face scan each day.")
            bullet("Keep your streak by scanning at least once every day.")
            bullet("Miss one day? A Streak Freeze is used automatically if you have one.")
            bullet("Earn 1 Streak Freeze for every 7-day streak.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
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
