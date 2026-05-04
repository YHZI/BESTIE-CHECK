//
//  Models.swift
//  Bestie-Check
//
//  Created for Face Mesh AI Bubble Demo
//

import Foundation
import CoreVideo

/// Swift 6 并发规则下，`CVPixelBuffer` 不符合 `Sendable`。
/// 我们用一个 `@unchecked Sendable` 的包装来在 AsyncStream / Task 中传递“引用”，并由调用方保证不会跨线程同时读写同一个 buffer。
struct PixelBufferBox: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
}

// MARK: - Face Analysis Summary (发送给 AI 的结构化数据)
struct FaceAnalysisSummary: Codable {
    let hasFace: Bool
    let numFaces: Int
    let blendshapesTop: [BlendshapeScore]
    let landmarkStats: LandmarkStats
    let timestampMs: Int64
    
    struct BlendshapeScore: Codable {
        let name: String
        let score: Double
    }
    
    struct LandmarkStats: Codable {
        let mouthOpen: Double          // 嘴巴张开程度 (0-1)
        let eyeBlinkLeft: Double       // 左眼眨眼程度 (0-1)
        let eyeBlinkRight: Double      // 右眼眨眼程度 (0-1)
        let eyebrowRaise: Double       // 眉毛抬起程度 (0-1)
        let headPoseYaw: Double?       // 头部左右转动角度（度）
        let headPosePitch: Double?     // 头部上下点头角度（度）
        let headPoseRoll: Double?      // 头部左右倾斜角度（度）
    }
}

// MARK: - AI API Request/Response
struct AIRequest: Codable {
    let faceAnalysis: FaceAnalysisSummary
    let imageBase64: String?  // 可选：如果启用上传整图模式
}

/// 后端 `POST /api/face-analysis` 返回体（兼容仅含 `message` 的旧格式）
struct AIResponse: Codable {
    let message: String?
    let summary: String?
    let detail: String?
    let funFact: String?
    let error: String?

    /// 解析为三段式反馈；缺字段时回退到 `message` 整段作为 summary
    func toFeedback() -> AIFeedback {
        let msg = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let s = (summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let d = (detail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let f = (funFact ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if s.isEmpty, d.isEmpty, f.isEmpty, !msg.isEmpty {
            return AIFeedback(summary: msg, detail: "", funFact: "")
        }
        return AIFeedback(
            summary: s.isEmpty ? msg : s,
            detail: d,
            funFact: f
        )
    }
}

/// AI 结构化妆容反馈（与后端 summary / detail / fun_fact 对应）
struct AIFeedback: Sendable {
    let summary: String
    let detail: String
    let funFact: String

    var composedForShare: String {
        [summary, detail, funFact]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

// MARK: - Frame with Timestamp
struct TimestampedFrameBox: @unchecked Sendable {
    let pixelBufferBox: PixelBufferBox
    let timestampMs: Int64
}
