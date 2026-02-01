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

// MARK: - Helper: 从 FaceLandmarkerResult 提取摘要（简化版）
extension FaceLandmarkerService {
    /// 将 MediaPipe 结果转换为 FaceAnalysisSummary（仅使用是否有脸和数量，先保证可编译可运行）
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

        return FaceAnalysisSummary(
            hasFace: true,
            numFaces: result.faceLandmarks.count,
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
}
