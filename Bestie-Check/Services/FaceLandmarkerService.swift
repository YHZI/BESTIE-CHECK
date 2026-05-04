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
    private var isModelLoading = false
    private var isModelReady = false

    /// 复用同一个 CIContext（创建代价极高，每帧新建会严重拖慢性能）
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Initialization
    override init() {
        super.init()
        // 不再在 init 中加载模型，改为懒加载或显式调用 prepareModel()
        print("📦 FaceLandmarkerService initialized (model will load on demand)")
    }
    
    /// 异步准备模型（可由 ResourcePreloader 或首次使用时调用）
    func prepareModel() async {
        guard !isModelReady && !isModelLoading else {
            return
        }
        
        isModelLoading = true
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            processingQueue.async { [weak self] in
                self?.setupFaceLandmarker()
                self?.isModelLoading = false
                self?.isModelReady = true
                continuation.resume()
            }
        }
    }

    private func setupFaceLandmarker() {
        guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
            print("❌ face_landmarker.task not found in Bundle.")
            return
        }

        let options = FaceLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .image
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
    /// ARKit 前置摄像头的 pixelBuffer 固定为 landscape-right 方向，
    /// 只需尝试 .right（和镜像 .rightMirrored）两次，不再暴力穷举 10 个方向。
    func detectSync(pixelBuffer: CVPixelBuffer) -> FaceLandmarkerResult? {
        // 懒加载：如果模型未准备好，返回 nil（上层会在首次调用前通过 prepareModel 预加载）
        guard let faceLandmarker else {
            return nil
        }

        // UIImage 路径：ARKit 前置 buffer 固定 .right，尝试 .right 和 .rightMirrored
        if let cgImage = pixelBufferToCGImage(pixelBuffer) {
            let orientationsToTry: [UIImage.Orientation] = [.right, .rightMirrored]
            for orientation in orientationsToTry {
                let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
                if let mpImage = try? MPImage(uiImage: uiImage),
                   let result = try? faceLandmarker.detect(image: mpImage),
                   !result.faceLandmarks.isEmpty {
                    return result
                }
            }
            // 无脸时返回最后一次检测结果（faces 为空，供上层判断无脸状态）
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            if let mpImage = try? MPImage(uiImage: uiImage),
               let result = try? faceLandmarker.detect(image: mpImage) {
                return result
            }
        }

        // 回退：直接用 pixelBuffer
        if let mpImage = try? MPImage(pixelBuffer: pixelBuffer, orientation: .right),
           let result = try? faceLandmarker.detect(image: mpImage) {
            return result
        }
        return nil
    }

    /// CIContext 复用版本：pixelBuffer → CGImage（不再每次 new CIContext）
    private func pixelBufferToCGImage(_ pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return Self.ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    // MARK: - Async wrapper
    /// 异步封装：在后台队列跑 detectSync，不阻塞主线程
    func processFrame(_ pixelBuffer: CVPixelBuffer, timestampMs: Int64) async throws -> FaceLandmarkerResult? {
        // PixelBufferBox 是 @unchecked Sendable，可安全跨 actor 边界传递
        let box = PixelBufferBox(pixelBuffer: pixelBuffer)
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: self.detectSync(pixelBuffer: box.pixelBuffer))
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
