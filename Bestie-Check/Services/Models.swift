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

struct AIResponse: Codable {
    let message: String          // 完整回复（兼容旧版）
    let summary: String?         // 摘要（简短版本）
    let detail: String?          // 详细内容（完整版本）
    let funfact: String?         // 趣味知识
    let error: String?
}

// MARK: - Frame with Timestamp
struct TimestampedFrameBox: @unchecked Sendable {
    let pixelBufferBox: PixelBufferBox
    let timestampMs: Int64
}
