//
//  HistoryDetailView.swift
//  Bestie-Check
//

import SwiftUI

struct HistoryDetailView: View {
    let record: AnalysisHistoryRecord
    @ObservedObject private var store = AnalysisHistoryStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let image = store.image(for: record) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))

                section(title: "Summary", body: record.summary)

                if !record.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    section(title: "Detail", body: record.detail)
                }

                if !record.funFact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    section(title: "Fun Fact", body: record.funFact)
                }
            }
            .padding(20)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
                .textCase(.uppercase)

            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        HistoryDetailView(
            record: AnalysisHistoryRecord(
                id: UUID(),
                createdAt: Date(),
                summary: "Your blush looks soft and natural.",
                detail: "• Lips: Nice gradient\n• Cheeks: Well blended",
                funFact: "Blush on the apples of your cheeks can make you look more youthful.",
                bubbleText: "",
                imageFileName: nil
            )
        )
    }
}
