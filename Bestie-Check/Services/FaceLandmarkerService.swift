//
//  FaceLandmarkerService.swift
//  Bestie-Check
//
//  MediaPipe Face Landmarker 推理层
//

import Foundation
import MediaPipeTasksVision
import CoreVideo
import CoreImage
import UIKit

/// FaceLandmarkerService: 使用 MediaPipe Tasks Vision 进行人脸关键点检测
class FaceLandmarkerService: NSObject {
    // MARK: - Properties
    private var faceLandmarker: FaceLandmarker?
    private let processingQueue = DispatchQueue(label: "com.facemesh.processing", qos: .userInitiated)
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupFaceLandmarker()
    }
    
    private func setupFaceLandmarker() {
        guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
            print("❌ face_landmarker.task not found in Bundle. Please download and add to project.")
            return
        }
        
        let options = FaceLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .image  // 使用 image 模式，同步返回结果，避免 livestream delegate 匹配问题
        options.outputFaceBlendshapes = true
        options.outputFacialTransformationMatrixes = true
        
        do {
            faceLandmarker = try FaceLandmarker(options: options)
            print("✅ FaceLandmarker initialized (image mode)")
        } catch {
            print("❌ Failed to initialize FaceLandmarker: \(error)")
        }
    }
    
    // MARK: - Detection (Image mode，同步，在后台队列执行)
    /// 在后台队列执行检测，返回结果（无脸时 result.faceLandmarks 为空，仍返回 result）。
    /// 前置 AR 画面会尝试 UIImage 路径 + 多种 orientation，提高检出率。
    func detectSync(pixelBuffer: CVPixelBuffer) -> FaceLandmarkerResult? {
        guard let faceLandmarker = faceLandmarker else {
            print("[detectSync] faceLandmarker nil")
            return nil
        }
        
        // 1) 用 UIImage 路径 + 多种 orientation（前置摄像头常见 .right / .left）
        if let uiImage = pixelBufferToUIImage(pixelBuffer) {
            print("[detectSync] UIImage created ok, size=\(uiImage.size)")
            let orientations: [UIImage.Orientation] = [.up, .right, .left, .down, .rightMirrored, .leftMirrored]
            for orientation in orientations {
                let oriented = UIImage(cgImage: uiImage.cgImage!, scale: uiImage.scale, orientation: orientation)
                if let mpImage = try? MPImage(uiImage: oriented),
                   let result = try? faceLandmarker.detect(image: mpImage) {
                    print("[detectSync] UIImage orientation=\(orientation.rawValue) faces=\(result.faceLandmarks.count)")
                    if !result.faceLandmarks.isEmpty {
                        print("[detectSync] ✅ return from UIImage path, faces=\(result.faceLandmarks.count)")
                        return result
                    }
                } else {
                    print("[detectSync] UIImage orientation=\(orientation.rawValue) MPImage or detect failed")
                }
            }
            // 返回任意一次成功 detect 的 result（含无脸）
            if let mpImage = try? MPImage(uiImage: uiImage), let result = try? faceLandmarker.detect(image: mpImage) {
                print("[detectSync] return from UIImage .up fallback, faces=\(result.faceLandmarks.count)")
                return result
            }
            print("[detectSync] UIImage path: no result")
        } else {
            print("[detectSync] pixelBufferToUIImage failed")
        }
        
        // 2) 回退：直接用 pixelBuffer + 多种 orientation
        let orientations: [UIImage.Orientation] = [.up, .right, .left]
        for orientation in orientations {
            if let mpImage = try? MPImage(pixelBuffer: pixelBuffer, orientation: orientation),
               let result = try? faceLandmarker.detect(image: mpImage) {
                print("[detectSync] pixelBuffer orientation=\(orientation.rawValue) faces=\(result.faceLandmarks.count)")
                if !result.faceLandmarks.isEmpty {
                    print("[detectSync] ✅ return from pixelBuffer path, faces=\(result.faceLandmarks.count)")
                    return result
                }
            }
        }
        if let mpImage = try? MPImage(pixelBuffer: pixelBuffer, orientation: .up),
           let result = try? faceLandmarker.detect(image: mpImage) {
            print("[detectSync] return from pixelBuffer .up fallback, faces=\(result.faceLandmarks.count)")
            return result
        }
        print("[detectSync] return nil (all paths failed)")
        return nil
    }
    
    private func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /// 异步封装：在后台队列跑 detectSync，不阻塞主线程
    func processFrame(_ pixelBuffer: CVPixelBuffer, timestampMs: Int64) async throws -> FaceLandmarkerResult? {
        try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                let result = self.detectSync(pixelBuffer: pixelBuffer)
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - Helper: 从 FaceLandmarkerResult 提取完整摘要（blendshapes + landmark 统计 + 可选 head pose）
extension FaceLandmarkerService {
    /// 将 MediaPipe 结果转换为 FaceAnalysisSummary，填满 blendshapes 与 landmark 数据
    static func extractSummary(from result: FaceLandmarkerResult?, timestampMs: Int64) -> FaceAnalysisSummary? {
        guard let result = result, !result.faceLandmarks.isEmpty else {
            return FaceAnalysisSummary(
                hasFace: false,
                numFaces: 0,
                blendshapesTop: [],
                landmarkStats: FaceAnalysisSummary.LandmarkStats(
                    mouthOpen: 0,
                    eyeBlinkLeft: 0,
                    eyeBlinkRight: 0,
                    eyebrowRaise: 0,
                    headPoseYaw: nil,
                    headPosePitch: nil,
                    headPoseRoll: nil
                ),
                timestampMs: timestampMs
            )
        }

        var blendshapesTop: [FaceAnalysisSummary.BlendshapeScore] = []
        var mouthOpen: Double = 0
        var eyeBlinkLeft: Double = 0
        var eyeBlinkRight: Double = 0
        var eyebrowRaise: Double = 0
        var headPoseYaw: Double?
        var headPosePitch: Double?
        var headPoseRoll: Double?

        // 第一张脸的 blendshapes（MediaPipe: faceBlendshapes 为 [Classifications]，取 first 得到该脸的分类列表）
        let firstFaceClassifications = result.faceBlendshapes.first
        if let firstFace = firstFaceClassifications {
            let categories = firstFace.categories
            let list = categories.map { FaceAnalysisSummary.BlendshapeScore(name: $0.categoryName ?? "", score: Double($0.score)) }
            blendshapesTop = Array(list.sorted { $0.score > $1.score }.prefix(8))

            for b in categories {
                let name = b.categoryName ?? ""
                let score = Double(b.score)
                switch name {
                case "mouthOpen", "mouth_open": mouthOpen = max(mouthOpen, score)
                case "eyeBlinkLeft", "eye_blink_left": eyeBlinkLeft = max(eyeBlinkLeft, score)
                case "eyeBlinkRight", "eye_blink_right": eyeBlinkRight = max(eyeBlinkRight, score)
                case "browInnerUp", "brow_inner_up", "eyebrowRaise": eyebrowRaise = max(eyebrowRaise, score)
                default: break
                }
            }
        }

        // 从变换矩阵解析头部姿态（facialTransformationMatrixes 为非可选 [TransformMatrix]，data 为指针）
        if !result.facialTransformationMatrixes.isEmpty, let first = result.facialTransformationMatrixes.first {
            let ptr = first.data
            let data: [Float] = (0..<16).map { ptr.advanced(by: $0).pointee }
            if data.count >= 12 {
                let (yaw, pitch, roll) = eulerAnglesFromTransformationMatrix(data)
                headPoseYaw = yaw
                headPosePitch = pitch
                headPoseRoll = roll
            }
        }

        return FaceAnalysisSummary(
            hasFace: true,
            numFaces: result.faceLandmarks.count,
            blendshapesTop: blendshapesTop,
            landmarkStats: FaceAnalysisSummary.LandmarkStats(
                mouthOpen: mouthOpen,
                eyeBlinkLeft: eyeBlinkLeft,
                eyeBlinkRight: eyeBlinkRight,
                eyebrowRaise: eyebrowRaise,
                headPoseYaw: headPoseYaw,
                headPosePitch: headPosePitch,
                headPoseRoll: headPoseRoll
            ),
            timestampMs: timestampMs
        )
    }

    /// 从 4x4 变换矩阵（行优先，至少 12 个元素）提取欧拉角（度）
    private static func eulerAnglesFromTransformationMatrix(_ data: [Float]) -> (yaw: Double?, pitch: Double?, roll: Double?) {
        guard data.count >= 12 else { return (nil, nil, nil) }
        let r00 = Double(data[0]), r10 = Double(data[4]), r20 = Double(data[8])
        let r21 = Double(data[9]), r22 = Double(data[10])
        var pitch = asin(-r20)
        if abs(cos(pitch)) < 1e-6 { pitch = 0 }
        let yaw = atan2(r10 / cos(pitch), r00 / cos(pitch))
        let roll = atan2(r21 / cos(pitch), r22 / cos(pitch))
        let toDeg = 180.0 / Double.pi
        return (yaw * toDeg, pitch * toDeg, roll * toDeg)
    }
}
