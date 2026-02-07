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
    @Published var uploadFullImage: Bool = false
    @Published var showNoFaceMessage: Bool = true
    
    // MARK: - Private Properties
    private let arFrameProvider = ARFrameProvider()
    private let faceLandmarkerService = FaceLandmarkerService()
    private let aiClient = AIClient()
    
    private var frameTask: Task<Void, Never>?
    private var lastProcessedTimestamp: Int64 = 0
    private var bubbleAutoHideTask: Task<Void, Never>?
    
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
            // 推理失败或未检测到人脸
            if showNoFaceMessage {
                updateBubble(text: "No face detected", autoHide: true)
            }
            return
        }
        
        // 2. 提取摘要
        guard let summary = FaceLandmarkerService.extractSummary(from: result, timestampMs: timestampMs) else {
            return
        }
        
        // 如果没有检测到脸，可选显示提示
        if !summary.hasFace {
            if showNoFaceMessage {
                updateBubble(text: "No face detected", autoHide: true)
            }
            return
        }
        
        // 3. 调用 AI API（后台任务）
        isLoading = true
        errorMessage = nil
        
        do {
            // 可选：准备图片 base64
            let imageBase64 = uploadFullImage ? AIClient.pixelBufferToBase64(pixelBuffer) : nil
            
            // 调用 AI
            let aiReply = try await aiClient.getAIReply(
                summary: summary,
                includeImage: uploadFullImage,
                imageBase64: imageBase64
            )
            
            // 4. 更新 UI（主线程）
            updateBubble(text: aiReply, autoHide: true)
            isLoading = false
            
        } catch {
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
}
