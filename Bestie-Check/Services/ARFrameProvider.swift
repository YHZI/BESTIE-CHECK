//
//  ARFrameProvider.swift
//  Bestie-Check
//
//  ARKit 取帧层：从 ARSession 获取实时相机帧
//

import ARKit
import AVFoundation
import Combine
import RealityKit

/// ARFrameProvider: 管理 ARSession，提供实时相机帧流
@MainActor
class ARFrameProvider: NSObject, ObservableObject {
    // MARK: - Properties
    private var arSession: ARSession?
    private var frameContinuation: AsyncStream<TimestampedFrameBox>.Continuation?
    private var isSessionRunning: Bool = false
    
    /// 输出：最新帧流（带时间戳）
    var frameStream: AsyncStream<TimestampedFrameBox>?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupFrameStream()
    }
    
    private func setupFrameStream() {
        var continuation: AsyncStream<TimestampedFrameBox>.Continuation?
        // bufferingPolicy: .bufferingNewest(1)
        // ARKit delegate 以 ~60fps yield 帧，下游 processFrame 因节流只消费 5fps。
        // 默认的 .unbounded 缓冲会让 CVPixelBuffer 持续堆积，导致
        // "ARSession is retaining N ARFrames" 警告并最终冻结相机。
        // 仅保留最新 1 帧：旧帧自动丢弃，CVPixelBuffer 立即释放回 ARKit 池。
        frameStream = AsyncStream<TimestampedFrameBox>(bufferingPolicy: .bufferingNewest(1)) { cont in
            continuation = cont
        }
        frameContinuation = continuation
    }
    
    // MARK: - ARSession Management
    func startSession(arView: ARView) {
        arSession = arView.session
        arSession?.delegate = self
        
        // 优先尝试 Face Tracking（需要 TrueDepth）
        if ARFaceTrackingConfiguration.isSupported {
            let configuration = ARFaceTrackingConfiguration()
            configuration.maximumNumberOfTrackedFaces = 1
            arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            isSessionRunning = true
            print("✅ ARFaceTrackingConfiguration started")
        } else {
            // 降级：使用 World Tracking（ARKit 会使用后置摄像头）
            let configuration = ARWorldTrackingConfiguration()
            arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            isSessionRunning = true
            print("⚠️ ARWorldTrackingConfiguration started (Face Tracking not supported)")
        }
    }
    
    func stopSession() {
        arSession?.pause()
        arSession = nil
        isSessionRunning = false
    }
    
    /// 暂停 ARSession（释放摄像头），但保留 arSession 引用以便后续恢复
    func pauseSession() {
        guard isSessionRunning else {
            print("⚠️ ARSession already paused, skipping")
            return
        }
        arSession?.pause()
        isSessionRunning = false
        print("⏸️ ARSession paused (camera released)")
    }
    
    /// 恢复 ARSession（重新占用摄像头）
    func resumeSession() {
        guard let arSession else {
            print("❌ Cannot resume: arSession is nil")
            return
        }
        guard !isSessionRunning else {
            print("⚠️ ARSession already running, skipping resume")
            return
        }
        if ARFaceTrackingConfiguration.isSupported {
            let configuration = ARFaceTrackingConfiguration()
            configuration.maximumNumberOfTrackedFaces = 1
            arSession.run(configuration, options: [])
            isSessionRunning = true
            print("▶️ ARSession resumed (face tracking)")
        } else {
            let configuration = ARWorldTrackingConfiguration()
            arSession.run(configuration, options: [])
            isSessionRunning = true
            print("▶️ ARSession resumed (world tracking)")
        }
    }
}

// MARK: - ARSessionDelegate
extension ARFrameProvider: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // 获取相机原始画面（CVPixelBuffer）
        let pixelBuffer = frame.capturedImage
        
        // 计算时间戳（毫秒）
        let timestampMs = Int64(frame.timestamp * 1000)
        
        // 发送到流（注意：这里需要回到 MainActor 来访问 continuation）
        Task { @MainActor in
            frameContinuation?.yield(
                TimestampedFrameBox(
                    pixelBufferBox: PixelBufferBox(pixelBuffer: pixelBuffer),
                    timestampMs: timestampMs
                )
            )
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        print("❌ ARSession error: \(error.localizedDescription)")
    }
    
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        print("⚠️ ARSession interrupted")
    }
    
    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        print("✅ ARSession interruption ended")
    }
}
