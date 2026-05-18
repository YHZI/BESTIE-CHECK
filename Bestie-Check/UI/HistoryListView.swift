//
//  HistoryListView.swift
//  Bestie-Check
//

import SwiftUI

struct HistoryListView: View {
    @ObservedObject private var store = AnalysisHistoryStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    emptyState
                } else {
                    List(store.records) { record in
                        NavigationLink(value: record) {
                            HistoryRowView(record: record)
                        }
                        .listRowBackground(Color.white.opacity(0.06))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(store.records.count)/\(AnalysisHistoryStore.maxRecordCount)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .navigationDestination(for: AnalysisHistoryRecord.self) { record in
                HistoryDetailView(record: record)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.35))
            Text("No history yet")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            Text("Your AI analysis results will appear here.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct HistoryRowView: View {
    let record: AnalysisHistoryRecord
    @ObservedObject private var store = AnalysisHistoryStore.shared

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(record.summary.isEmpty ? "Analysis" : record.summary)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = store.image(for: record) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                Image(systemName: "face.smiling")
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}

/// Main-screen history entry (matches BackButton visual style).
struct HistoryToolbarButton: View {
    var action: () -> Void
    var diameter: CGFloat = 22

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: diameter * 0.5, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .opacity(isPressed ? 0.7 : 1.0)
            .frame(width: max(44, diameter), height: max(44, diameter))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
        .accessibilityLabel("Analysis history")
    }
}

#Preview {
    HistoryListView()
}
