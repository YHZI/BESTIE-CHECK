//
//  FaceMeshAssistantViewModel.swift
//  Bestie-Check
//
//  ViewModel: 状态管理与业务逻辑协调
//

import SwiftUI
import ARKit
import RealityKit
import Combine
import UIKit

@MainActor
class FaceMeshAssistantViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var bubbleText: String = ""
    @Published var isBubbleVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var shouldExpandBubble: Bool = false  // 控制气泡是否应该展开（仅AI响应时为true）
    
    // MARK: - Share
    /// 用户可分享的妆容照片（使用“发给 AI 的那张”）
    @Published var lastSharedImage: UIImage?
    
    // MARK: - Debug Settings
    @Published var throttleIntervalMs: Int = 200  // 默认 5fps (1000/200)
    @Published var uploadFullImage: Bool = true  // 默认上传人脸图给 AI，与 landmark 数据一起获得更好回答
    @Published var showNoFaceMessage: Bool = true
    
    // MARK: - Private Properties
    private let arFrameProvider = ARFrameProvider()
    private let faceLandmarkerService = FaceLandmarkerService()
    private let aiClient = AIClient(config: .backendProxy)
    
    private var frameTask: Task<Void, Never>?
    private var lastProcessedTimestamp: Int64 = 0
    private var bubbleAutoHideTask: Task<Void, Never>?
    /// 当前「有脸」会话内是否已经请求过 AI；脸消失后重置，实现「有脸只回复一次」
    private var hasRepliedForCurrentFaceSession: Bool = false
    private var consecutiveFaceFrames: Int = 0
    private var consecutiveNoFaceFrames: Int = 0
    private let requiredFaceFrames: Int = 3
    private let requiredNoFaceFrames: Int = 3
    /// 稳定有脸后，再等这么久才向 AI 发送（避免第一帧数据不完整）
    private let aiRequestDelayAfterStableFaceMs: Int64 = 1000
    /// 首次达到「稳定有脸」时的墙钟时间（ms）；人脸离开后清零
    private var stableFaceAnchorWallMs: Int64?
    
    // MARK: - Initialization
    init() {
        startFrameProcessing()
    }
    
    // MARK: - AR Session Management
    func setupARSession(arView: ARView) {
        arFrameProvider.startSession(arView: arView)
    }
    
    func stopARSession() {
        arFrameProvider.stopSession()
        frameTask?.cancel()
        bubbleAutoHideTask?.cancel()
    }
    
    /// Share 流程打开时调用：暂停 ARSession 释放摄像头，避免与 AVCaptureSession 竞争
    func pauseARSession() {
        arFrameProvider.pauseSession()
        frameTask?.cancel()
        frameTask = nil
    }
    
    /// Share 流程关闭时调用：恢复 ARSession
    func resumeARSession() {
        arFrameProvider.resumeSession()
        startFrameProcessing()
    }
    
    // MARK: - Frame Processing Pipeline
    private func startFrameProcessing() {
        frameTask = Task { [weak self] in
            guard let self = self,
                  let frameStream = self.arFrameProvider.frameStream else {
                return
            }
            
            for await frame in frameStream {
                // 检查是否取消
                if Task.isCancelled { break }
                
                // 节流控制
                let currentTimestamp = Int64(Date().timeIntervalSince1970 * 1000)
                let timeSinceLastProcess = currentTimestamp - self.lastProcessedTimestamp
                
                if timeSinceLastProcess < Int64(self.throttleIntervalMs) {
                    continue  // 跳过此帧
                }
                
                // 更新最后处理时间
                self.lastProcessedTimestamp = currentTimestamp
                
                // 异步处理帧（不阻塞主线程）
                await self.processFrame(frame.pixelBufferBox.pixelBuffer, timestampMs: frame.timestampMs)
            }
        }
    }
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer, timestampMs: Int64) async {
        // 1. Face Landmarker 推理（后台队列）
        guard let result = try? await faceLandmarkerService.processFrame(pixelBuffer, timestampMs: timestampMs) else {
            // 推理失败或未检测到人脸 → 结束当前「有脸」会话，下次有脸会重新请求 AI
            hasRepliedForCurrentFaceSession = false
            stableFaceAnchorWallMs = nil
            FaceDetectionProvider.shared.updateFaceDetection(detected: false)
            if showNoFaceMessage {
                updateBubble(text: "No face detected", autoHide: true, isAIResponse: false)
            }
            return
        }
        
        // 2. 提取摘要
        guard let summary = FaceLandmarkerService.extractSummary(from: result, timestampMs: timestampMs) else {
            setFaceDetectedState(false)
            return
        }
        
        if !summary.hasFace {
            setFaceDetectedState(false)
            return
        }
        
        // 检测到人脸，进入有脸计数逻辑
        setFaceDetectedState(true)

        if consecutiveFaceFrames < requiredFaceFrames {
            return
        }

        let nowWallMs = Int64(Date().timeIntervalSince1970 * 1000)
        if stableFaceAnchorWallMs == nil {
            stableFaceAnchorWallMs = nowWallMs
        }
        guard let anchor = stableFaceAnchorWallMs, nowWallMs - anchor >= aiRequestDelayAfterStableFaceMs else {
            return
        }

        // 本「有脸」会话内已经请求过 AI → 不再重复请求，保持当前气泡
        if hasRepliedForCurrentFaceSession {
            return
        }
        
        // 3. 稳定有脸满 1 秒后，用当前帧调用 AI 一次
        hasRepliedForCurrentFaceSession = true
        isLoading = true
        errorMessage = nil
        
        do {
            let imageBase64 = uploadFullImage ? AIClient.pixelBufferToBase64(pixelBuffer) : nil
            if uploadFullImage {
                lastSharedImage = AIClient.pixelBufferToUIImage(pixelBuffer)
            } else {
                lastSharedImage = nil
            }
            let aiReply = try await aiClient.getAIReply(
                summary: summary,
                includeImage: uploadFullImage,
                imageBase64: imageBase64
            )
            updateBubble(text: aiReply, autoHide: true, isAIResponse: true)
            isLoading = false
        } catch {
            // 请求失败时允许下次有脸再试
            hasRepliedForCurrentFaceSession = false
            isLoading = false
            errorMessage = "AI API Error: \(error.localizedDescription)"
            print("❌ AI API error: \(error)")
        }
    }
    
    // MARK: - Bubble Management
    private func updateBubble(text: String, autoHide: Bool = true, isAIResponse: Bool = false) {
        bubbleText = text
        isBubbleVisible = true
        
        // 只有AI响应才展开气泡
        shouldExpandBubble = isAIResponse
        
        // 取消之前的自动隐藏任务
        bubbleAutoHideTask?.cancel()
        
        if autoHide {
            // 3-5 秒后自动隐藏；Task 取消时 sleep 抛出 CancellationError，自动退出
            let hideDelay = Double.random(in: 3.0...5.0)
            bubbleAutoHideTask = Task { [weak self] in
                do {
                    try await Task.sleep(nanoseconds: UInt64(hideDelay * 1_000_000_000))
                    self?.isBubbleVisible = false  // 已在 @MainActor 上，无需 MainActor.run
                } catch {
                    // Task was cancelled — do nothing
                }
            }
        }
    }
    
    func hideBubble() {
        bubbleAutoHideTask?.cancel()
        isBubbleVisible = false
    }
    
    // MARK: - Detection Reset
    private func setFaceDetectedState(_ detected: Bool) {
        if detected {
            consecutiveFaceFrames += 1
            consecutiveNoFaceFrames = 0

            if consecutiveFaceFrames >= requiredFaceFrames {
                FaceDetectionProvider.shared.updateFaceDetection(detected: true)
            }
        } else {
            consecutiveNoFaceFrames += 1
            consecutiveFaceFrames = 0
            stableFaceAnchorWallMs = nil

            if consecutiveNoFaceFrames >= requiredNoFaceFrames {
                hasRepliedForCurrentFaceSession = false
                FaceDetectionProvider.shared.updateFaceDetection(detected: false)
                if showNoFaceMessage {
                    updateBubble(text: "No face detected", autoHide: true, isAIResponse: false)
                }
            }
        }
    }

    /// 重置后台检测状态
    func resetDetection() {
        print("🔄 ViewModel: Resetting detection state...")
        
        lastProcessedTimestamp = 0
        hasRepliedForCurrentFaceSession = false
        stableFaceAnchorWallMs = nil
        consecutiveFaceFrames = 0
        consecutiveNoFaceFrames = 0
        bubbleText = ""
        isBubbleVisible = false
        shouldExpandBubble = false  // 重置展开信号
        lastSharedImage = nil
        bubbleAutoHideTask?.cancel()
        errorMessage = nil
        isLoading = false
        
        print("✅ ViewModel: Detection state reset completed")
    }
    
    // MARK: - Post-Share Reset
    /// 分享完成后，重置 UI 到欢迎状态：收起气泡、清空AI内容、重填默认问候
    func resetToWelcome() {
        bubbleAutoHideTask?.cancel()
        shouldExpandBubble = false          // 气泡收起
        bubbleText = ""                     // 清空 AI 内容
        isBubbleVisible = true             // 保持可见，显示问候
        hasRepliedForCurrentFaceSession = false  // 允许下次有脸重新触发 AI
        stableFaceAnchorWallMs = nil
        consecutiveFaceFrames = 0
        consecutiveNoFaceFrames = 0
        lastSharedImage = nil
        errorMessage = nil
        isLoading = false
        // bubbleText 置空后 ContentView 的 displayText 会自动回退到 "Hello! 😊"
    }

    // MARK: - Manual Trigger
    func triggerManualAnalysis() {
        // 手动触发一次分析（需要当前帧）
        // 注意：这里简化实现，实际应该从 ARFrameProvider 获取最新帧
        Task {
            // TODO: 获取最新帧并处理
            updateBubble(text: "Manual analysis triggered (feature coming soon)", autoHide: true, isAIResponse: false)
        }
    }
    
    // MARK: - Test Trigger
    func triggerTestBubble() {
        updateBubble(text: "Sorry! No face detected in AR scan.", autoHide: false, isAIResponse: false)
    }
    
    // MARK: - Debug Test Bubble
    /// 用于 Debug Panel 测试，直接注入文本到气泡（不影响业务逻辑）
    func injectTestText(_ text: String, autoHide: Bool = false, isAIResponse: Bool = true) {
        updateBubble(text: text, autoHide: autoHide, isAIResponse: isAIResponse)
    }
}
