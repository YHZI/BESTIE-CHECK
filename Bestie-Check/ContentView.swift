//
//  ContentView.swift
//  Bestie-Check
//
//  主界面：ARView + 气泡 overlay + 调试面板
//

import SwiftUI
import RealityKit
import Combine

struct ContentView: View {
    @StateObject private var viewModel = FaceMeshAssistantViewModel()
    @ObservedObject private var faceDetectionProvider = FaceDetectionProvider.shared
    
    // 气泡框展开状态
    @State private var isBubbleExpanded: Bool = false
    
    // 测试文本模式（短文本/长文本）
    @State private var isLongTextMode: Bool = false
    
    // ViewFinder 扫描线开关
    @State private var showViewFinderScan: Bool = false
    
    // 背景模式：false = Camera, true = RGB Colors
    @State private var useRGBBackground: Bool = false
    
    /// User takes a new photo for share (not the first face frame).
    @State private var isShareCameraPresented: Bool = false
    
    /// Share 流程打开时冻结的文案与图（避免 preview 随 ViewModel 后台刷新而跳动）
    @State private var shareFrozenReplyText: String = ""
    @State private var shareFrozenPreImage: UIImage? = nil

    
    // 测试文本内容
    var testText: String {
        if isLongTextMode {
            return """
Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
"""
        } else {
            return viewModel.bubbleText.isEmpty ? "Hello! 😊" : viewModel.bubbleText
        }
    }
    
    var body: some View {
        ZStack {
            // AR 画面（全屏）
            ARViewContainer(viewModel: viewModel, useRGBBackground: $useRGBBackground)
                .ignoresSafeArea()
            
            // ViewFinder 取景框（全屏居中）- 展开时隐藏
            if !isBubbleExpanded {
                ViewFinder(
                    frameWidth: 280,
                    frameHeight: 360,
                    cornerLength: 30,
                    lineWidth: 3,
                    color: faceDetectionProvider.faceDetected ? .green : .white,
                    showScanLine: showViewFinderScan,
                    faceDetected: faceDetectionProvider.faceDetected
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isBubbleExpanded)
            }
            
            // ARIcon 组件（放在 ViewFinder 下面）- 展开时隐藏
            if !isBubbleExpanded {
                VStack {
                    Spacer()
                    ARIconView(
                        pupilPosition: CGPoint(x: 0.5, y: 0.5),
                        eyeSocketColor: .white,
                        pupilColor: .white,
                        strokeWidth: 3.5,
                        showDecorations: true,
                        enableBlinking: true
                    )
                    .frame(width: 56, height: 65)  // 70% of original 80x93
                    .opacity(0.7)  // 70% opacity
                    .padding(.bottom, 65)  // 65px from bottom
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isBubbleExpanded)
            }
            
            // AI 气泡 overlay（始终显示）
            VStack {
                ZStack(alignment: .topTrailing) {
                    // 气泡框 - 三个接口：title, text, isExpanded, shouldExpand
                    ReactTextBarWithCircle(
                        title: "",
                        text: testText,
                        isExpanded: $isBubbleExpanded,
                        shouldExpand: $viewModel.shouldExpandBubble,
                        shareEnabled: !viewModel.bubbleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        onShareTapped: {
                            // 与气泡里显示的文案一致（含长文本测试模式）
                            shareFrozenReplyText = testText
                            shareFrozenPreImage = viewModel.lastSharedImage
                            isShareCameraPresented = true
                        }
                    )
                    .onChange(of: isLongTextMode) { oldValue, newValue in
                        print("🔀 ContentView: isLongTextMode changed: \(oldValue) → \(newValue)")
                        print("📏 ContentView: testText length is now: \(testText.count)")
                        print("📖 ContentView: First 100 chars: \(String(testText.prefix(100)))")
                    }
                    
                    // LogoFrame 圆形叠加在气泡上
                    LogoFrame(
                        horizontalOffset: -6,
                        verticalOffset: 0,
                        imageScale: 1.2
                    )
                        .frame(height: 120)
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .zIndex(1)  // 固定 zIndex，不再动态提升
            .shareFlow(isPresented: $isShareCameraPresented, isBubbleExpanded: $isBubbleExpanded, replyText: shareFrozenReplyText, preCapturedImage: shareFrozenPreImage, viewModel: viewModel)
            
            // 左上角返回按钮（智能模式：自动处理 ReactTextBar 状态）
            VStack {
                HStack {
                    BackButton(
                        diameter: 22,
                        isTextBarExpanded: Binding(
                            get: { isBubbleExpanded ? true : nil },
                            set: { newValue in
                                if let value = newValue {
                                    isBubbleExpanded = value
                                } else {
                                    isBubbleExpanded = false
                                }
                            }
                        ),
                        onResetDetection: {
                            // 重置 APP 后台检测方法
                            print("🔄 Resetting backend detection...")
                            viewModel.resetDetection()
                        },
                        isLongTextMode: Binding(
                            get: { isLongTextMode ? true : nil },
                            set: { newValue in
                                if let value = newValue {
                                    isLongTextMode = value
                                } else {
                                    isLongTextMode = false
                                }
                            }
                        ),
                        action: {
                            // 额外的自定义操作（可选）
                            print("📍 Back button custom action executed")
                        }
                    )
                    .padding(.leading, 40)
                    .padding(.top, 24)
                    
                    Spacer()
                }
                Spacer()
            }
            .zIndex(100)  // 在气泡之上，调试面板之下
            
            // 调试面板（右上角）- 始终在最前端
            HStack {
                Spacer()
                DebugPanelView(
                    viewModel: viewModel,
                    isLongTextMode: $isLongTextMode,
                    showViewFinderScan: $showViewFinderScan,
                    useRGBBackground: $useRGBBackground
                )
            }
            .zIndex(1000)  // 始终在最前端
            
            // Loading 指示器
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
                .padding(16)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.bottom, 100)
            }
            
            // 错误提示
            if let errorMessage = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 200)
                        .onTapGesture {
                            viewModel.errorMessage = nil
                        }
                }
            }
        }
        .onAppear {
            // ViewModel 初始化时已启动处理
        }
        .onDisappear {
            viewModel.stopARSession()
        }
    }
}

#Preview {
    ContentView()
}
