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
    @Published var bubbleSummary: String = ""       // AI 响应摘要（先显示）
    @Published var bubbleDetail: String = ""        // AI 响应详情（后显示）
    @Published var funFactText: String = ""         // FunFact 文本
    @Published var isBubbleVisible: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var shouldExpandBubble: Bool = false  // 控制气泡是否应该展开（仅AI响应时为true）
    
    // MARK: - Share
    /// 用户可分享的妆容照片（使用"发给 AI 的那张"）
    @Published var lastSharedImage: UIImage?
    
    // MARK: - FunFact & Logo State
    /// FunFact 气泡显示状态
    @Published var showFunFact: Bool = false
    /// Logo 呼吸灯效果状态（FunFact 关闭后亮起）
    @Published var logoGlowing: Bool = false
    /// FunFact 是否已锁定（避免持续刷新）
    private var funFactLocked: Bool = false
    
    // MARK: - Debug Settings
    @Published var throttleIntervalMs: Int = 200  // 默认 5fps (1000/200)
    @Published var uploadFullImage: Bool = true  // 默认上传人脸图给 AI，与 landmark 数据一起获得更好回答
    @Published var showNoFaceMessage: Bool = true

    // MARK: - Reanalysis control
    /// Only auto-analyze once per app launch (first time opening the app).
    /// After that, analysis is allowed only when the user taps the Reanalysis button.
    @Published private(set) var canRequestReanalysis: Bool = true
    /// Whether the app has completed at least one analysis attempt this launch.
    /// Used by UI to decide when to show the "Re-scan" entry point.
    @Published private(set) var hasCompletedFirstAnalysis: Bool = false
    private var hasAutoAnalyzedThisLaunch: Bool = false
    private var isManualReanalysisArmed: Bool = false
    
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
        print("🔴 ViewModel: Pausing AR session")
        arFrameProvider.pauseSession()
        frameTask?.cancel()
        frameTask = nil
    }
    
    /// Share 流程关闭时调用：恢复 ARSession
    func resumeARSession() {
        // 防止重复恢复：如果已经有 frameTask 在运行，说明已经恢复过了
        guard frameTask == nil else {
            print("⚠️ ViewModel: AR session already resumed, skipping")
            return
        }
        print("🟢 ViewModel: Resuming AR session")
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

        // App-level gating:
        // - Allow exactly one automatic analysis per app launch.
        // - After that, require the user to explicitly arm a manual reanalysis.
        if hasAutoAnalyzedThisLaunch && !isManualReanalysisArmed {
            return
        }
        
        // 3. 稳定有脸满 1 秒后，用当前帧调用 AI 一次
        hasRepliedForCurrentFaceSession = true
        let wasManualReanalysis = isManualReanalysisArmed
        // Consume the manual trigger immediately so we don't auto-fire repeatedly on subsequent frames.
        isManualReanalysisArmed = false
        // Consume the one-time auto analysis as soon as we start an attempt.
        if !hasAutoAnalyzedThisLaunch && !wasManualReanalysis {
            hasAutoAnalyzedThisLaunch = true
        }
        isLoading = true
        errorMessage = nil
        canRequestReanalysis = false
        
        do {
            let imageBase64 = uploadFullImage ? AIClient.pixelBufferToBase64(pixelBuffer) : nil
            if uploadFullImage {
                lastSharedImage = AIClient.pixelBufferToUIImage(pixelBuffer)
            } else {
                lastSharedImage = nil
            }
            let aiResponse = try await aiClient.getAIResponse(
                summary: summary,
                includeImage: uploadFullImage,
                imageBase64: imageBase64
            )
            
            // 解析结构化响应
            bubbleSummary = aiResponse.summary ?? aiResponse.message
            bubbleDetail = aiResponse.detail ?? aiResponse.message
            
            // 拼接 summary 和 detail：上部分显示 summary，空一行后显示 detail
            if !bubbleSummary.isEmpty && !bubbleDetail.isEmpty && bubbleSummary != bubbleDetail {
                bubbleText = bubbleSummary + "\n\n" + bubbleDetail
            } else {
                bubbleText = bubbleSummary.isEmpty ? bubbleDetail : bubbleSummary
            }
            
            // 更新 FunFact（仅在未锁定时）
            if !funFactLocked, let funfact = aiResponse.funfact, !funfact.isEmpty {
                funFactText = funfact
                funFactLocked = true  // 锁定，等待下次扫描
            }
            
            updateBubble(text: bubbleText, autoHide: true, isAIResponse: true)
            hasCompletedFirstAnalysis = true
            isLoading = false
            canRequestReanalysis = true
        } catch {
            // 请求失败：不自动重试（避免在同一次会话里反复触发），交给用户点 Reanalysis 再来一次。
            isLoading = false
            canRequestReanalysis = true
            hasCompletedFirstAnalysis = true
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
        bubbleSummary = ""
        bubbleDetail = ""
        funFactText = ""
        funFactLocked = false  // 解锁 FunFact，允许下次更新
        isBubbleVisible = false
        shouldExpandBubble = false  // 重置展开信号
        lastSharedImage = nil
        bubbleAutoHideTask?.cancel()
        errorMessage = nil
        isLoading = false
        
        print("✅ ViewModel: Detection state reset completed")
    }

    /// User-facing reanalysis trigger.
    /// Arms exactly one new analysis run (when a face is stable again).
    func requestReanalysis() {
        guard !isLoading else { return }
        isManualReanalysisArmed = true
        canRequestReanalysis = false
        // Reset per-face-session gating so the next stable face can trigger.
        hasRepliedForCurrentFaceSession = false
        stableFaceAnchorWallMs = nil
        consecutiveFaceFrames = 0
        consecutiveNoFaceFrames = 0
        // 解锁 FunFact，允许新的分析更新 FunFact
        funFactLocked = false
    }
    
    // MARK: - Post-Share Reset
    /// 分享完成后，重置 UI 到欢迎状态：收起气泡、清空AI内容、重填默认问候
    func resetToWelcome() {
        bubbleAutoHideTask?.cancel()
        shouldExpandBubble = false          // 气泡收起
        bubbleText = ""                     // 清空 AI 内容
        bubbleSummary = ""
        bubbleDetail = ""
        isBubbleVisible = true             // 保持可见，显示问候
        // Do NOT re-enable automatic analysis here.
        // Auto analysis should only happen once per app launch.
        hasRepliedForCurrentFaceSession = false
        stableFaceAnchorWallMs = nil
        consecutiveFaceFrames = 0
        consecutiveNoFaceFrames = 0
        lastSharedImage = nil
        errorMessage = nil
        isLoading = false
        
        // 重置 FunFact 和 Logo 状态
        showFunFact = false
        logoGlowing = false
        // 注意：不解锁 funFactLocked，保持 funFactText 内容直到下次扫描
        
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
