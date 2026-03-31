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

@MainActor
class FaceMeshAssistantViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var bubbleText: String = ""
    @Published var isBubbleVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Debug Settings
    @Published var throttleIntervalMs: Int = 200  // 默认 5fps (1000/200)
    @Published var uploadFullImage: Bool = true  // 默认上传人脸图给 AI，与 landmark 数据一起获得更好回答
    @Published var showNoFaceMessage: Bool = true
    
    // MARK: - Private Properties
    private let arFrameProvider = ARFrameProvider()
    private let faceLandmarkerService = FaceLandmarkerService()
    private let aiClient: AIClient
    
    private var frameTask: Task<Void, Never>?
    private var lastProcessedTimestamp: Int64 = 0
    private var bubbleAutoHideTask: Task<Void, Never>?
    /// 当前「有脸」会话内是否已经请求过 AI；脸消失后重置，实现「有脸只回复一次」
    private var hasRepliedForCurrentFaceSession: Bool = false
    private var consecutiveFaceFrames: Int = 0
    private var consecutiveNoFaceFrames: Int = 0
    private let requiredFaceFrames: Int = 3
    private let requiredNoFaceFrames: Int = 3
    
    // MARK: - Initialization
    init() {
        #if DEBUG
        #if targetEnvironment(simulator)
        self.aiClient = AIClient(config: .default)
        #else
        self.aiClient = AIClient(config: .backendProxy)
        #endif
        #else
        self.aiClient = AIClient(config: .backendProxy)
        #endif
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
            await FaceDetectionProvider.shared.updateFaceDetection(detected: false)
            if showNoFaceMessage {
                updateBubble(text: "No face detected", autoHide: true)
            }
            return
        }
        
        // 2. 提取摘要
        guard let summary = FaceLandmarkerService.extractSummary(from: result, timestampMs: timestampMs) else {
            await setFaceDetectedState(false)
            return
        }
        
        // 如果没有检测到脸，进入无脸计数逻辑
        if !summary.hasFace {
            await setFaceDetectedState(false)
            return
        }
        
        // 检测到人脸，进入有脸计数逻辑
        await setFaceDetectedState(true)

        if consecutiveFaceFrames < requiredFaceFrames {
            return
        }

        // 本「有脸」会话内已经请求过 AI → 不再重复请求，保持当前气泡
        if hasRepliedForCurrentFaceSession {
            return
        }
        
        // 3. 本会话内首次有脸，调用 AI 一次
        hasRepliedForCurrentFaceSession = true
        isLoading = true
        errorMessage = nil
        
        do {
            let imageBase64 = uploadFullImage ? AIClient.pixelBufferToBase64(pixelBuffer) : nil
            let aiReply = try await aiClient.getAIReply(
                summary: summary,
                includeImage: uploadFullImage,
                imageBase64: imageBase64
            )
            updateBubble(text: aiReply, autoHide: true)
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
    private func updateBubble(text: String, autoHide: Bool = true) {
        bubbleText = text
        isBubbleVisible = true
        
        // 取消之前的自动隐藏任务
        bubbleAutoHideTask?.cancel()
        
        if autoHide {
            // 3-5 秒后自动隐藏
            let hideDelay = Double.random(in: 3.0...5.0)
            bubbleAutoHideTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(hideDelay * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        self.isBubbleVisible = false
                    }
                }
            }
        }
    }
    
    func hideBubble() {
        bubbleAutoHideTask?.cancel()
        isBubbleVisible = false
    }
    
    // MARK: - Detection Reset
    private func setFaceDetectedState(_ detected: Bool) async {
        if detected {
            consecutiveFaceFrames += 1
            consecutiveNoFaceFrames = 0

            if consecutiveFaceFrames >= requiredFaceFrames {
                await FaceDetectionProvider.shared.updateFaceDetection(detected: true)
            }
        } else {
            consecutiveNoFaceFrames += 1
            consecutiveFaceFrames = 0

            if consecutiveNoFaceFrames >= requiredNoFaceFrames {
                hasRepliedForCurrentFaceSession = false
                await FaceDetectionProvider.shared.updateFaceDetection(detected: false)
                if showNoFaceMessage {
                    updateBubble(text: "No face detected", autoHide: true)
                }
            }
        }
    }

    /// 重置后台检测状态
    func resetDetection() {
        print("🔄 ViewModel: Resetting detection state...")
        
        lastProcessedTimestamp = 0
        hasRepliedForCurrentFaceSession = false
        consecutiveFaceFrames = 0
        consecutiveNoFaceFrames = 0
        bubbleText = ""
        isBubbleVisible = false
        bubbleAutoHideTask?.cancel()
        errorMessage = nil
        isLoading = false
        
        print("✅ ViewModel: Detection state reset completed")
    }
    
    // MARK: - Manual Trigger
    func triggerManualAnalysis() {
        // 手动触发一次分析（需要当前帧）
        // 注意：这里简化实现，实际应该从 ARFrameProvider 获取最新帧
        Task {
            // TODO: 获取最新帧并处理
            updateBubble(text: "Manual analysis triggered (feature coming soon)", autoHide: true)
        }
    }
    
    // MARK: - Test Trigger
    func triggerTestBubble() {
        updateBubble(text: "Sorry! No face detected in AR scan.", autoHide: false)
    }
    
    // MARK: - Debug Test Bubble
    /// 用于 Debug Panel 测试，直接注入文本到气泡（不影响业务逻辑）
    func injectTestText(_ text: String, autoHide: Bool = false) {
        updateBubble(text: text, autoHide: autoHide)
    }
}
