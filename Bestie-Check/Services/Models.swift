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

/// AI 响应详细信息（各部位反馈）
struct AIResponseDetails: Codable {
    let eyebrows: String
    let eyelashes: String
    let eyeliner: String
    let aegyoSal: String      // aegyo_sal
    let nose: String
    let lips: String
    let cheeks: String
}

/// AI 响应结构（匹配后端 JSON 格式）
struct AIResponse: Codable {
    let summary: String          // 总体简短反馈
    let details: AIResponseDetails  // 各部位详细反馈
    let funFact: String          // fun_fact 趣味知识
    let error: String?           // 错误信息（可选）
    
    // 兼容旧版：将 details 转换为可读文本
    var detailsText: String {
        """
        Eyebrows: \(details.eyebrows)
        Eyelashes: \(details.eyelashes)
        Eyeliner: \(details.eyeliner)
        Aegyo Sal: \(details.aegyoSal)
        Nose: \(details.nose)
        Lips: \(details.lips)
        Cheeks: \(details.cheeks)
        """
    }
    
    // 完整消息（用于显示）
    var message: String {
        "\(summary)\n\n\(detailsText)"
    }
}

// MARK: - Frame with Timestamp
struct TimestampedFrameBox: @unchecked Sendable {
    let pixelBufferBox: PixelBufferBox
    let timestampMs: Int64
}
