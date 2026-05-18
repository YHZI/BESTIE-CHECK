//
//  AnalysisHistoryStore.swift
//  Bestie-Check
//
//  Offline local history: AI replies + photos sent to the agent (max 100).
//

import Foundation
import Combine
import UIKit

struct AnalysisHistoryRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let createdAt: Date
    let summary: String
    let detail: String
    let funFact: String
    let bubbleText: String
    /// File name under `images/` (e.g. "{uuid}.jpg")
    let imageFileName: String?

    var hasImage: Bool { imageFileName != nil }
}

@MainActor
final class AnalysisHistoryStore: ObservableObject {
    static let shared = AnalysisHistoryStore()

    static let maxRecordCount = 100

    @Published private(set) var records: [AnalysisHistoryRecord] = []

    private let indexFileName = "index.json"
    private let imagesDirectoryName = "images"

    private var storageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("AnalysisHistory", isDirectory: true)
    }

    private var imagesDirectory: URL {
        storageDirectory.appendingPathComponent(imagesDirectoryName, isDirectory: true)
    }

    private var indexFileURL: URL {
        storageDirectory.appendingPathComponent(indexFileName)
    }

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    func save(
        aiResponse: AIResponse,
        bubbleText: String,
        formattedDetail: String,
        image: UIImage?
    ) {
        let id = UUID()
        var imageFileName: String?

        if let image, let data = image.jpegData(compressionQuality: 0.82) {
            ensureDirectoriesExist()
            let fileName = "\(id.uuidString).jpg"
            let fileURL = imagesDirectory.appendingPathComponent(fileName)
            do {
                try data.write(to: fileURL, options: [.atomic])
                imageFileName = fileName
            } catch {
                print("❌ History: failed to write image – \(error)")
            }
        }

        let record = AnalysisHistoryRecord(
            id: id,
            createdAt: Date(),
            summary: aiResponse.summary,
            detail: formattedDetail,
            funFact: aiResponse.funFact,
            bubbleText: bubbleText,
            imageFileName: imageFileName
        )

        records.insert(record, at: 0)
        trimToMaxCount()
        persistIndex()
    }

    func image(for record: AnalysisHistoryRecord) -> UIImage? {
        guard let fileName = record.imageFileName else { return nil }
        let url = imagesDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Persistence

    private func ensureDirectoriesExist() {
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    private func loadFromDisk() {
        ensureDirectoriesExist()
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: indexFileURL.path) else {
            records = []
            return
        }

        do {
            let data = try Data(contentsOf: indexFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([AnalysisHistoryRecord].self, from: data)
        } catch {
            print("❌ History: failed to load index – \(error)")
            records = []
        }
    }

    private func persistIndex() {
        ensureDirectoriesExist()
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(records)
            try data.write(to: indexFileURL, options: [.atomic])
        } catch {
            print("❌ History: failed to save index – \(error)")
        }
    }

    private func trimToMaxCount() {
        while records.count > Self.maxRecordCount {
            let removed = records.removeLast()
            deleteImageFile(for: removed)
        }
    }

    private func deleteImageFile(for record: AnalysisHistoryRecord) {
        guard let fileName = record.imageFileName else { return }
        let url = imagesDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}
