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
    
    // 人脸检测接口（默认未检测到）
    private let faceDetectionProvider: FaceDetectionProvider = DefaultFaceDetectionProvider()
    
    // 气泡框展开状态
    @State private var isBubbleExpanded: Bool = false
    
    // 测试文本模式（短文本/长文本）
    @State private var isLongTextMode: Bool = false
    
    // 测试文本内容
    var testText: String {
        if isLongTextMode {
            return """
This is a very long text for testing the responsive behavior of the ReactTextBar component. When the text content exceeds the default frame size, the bubble should automatically expand and extend its right edge line all the way down to near the bottom of the screen.

The bubble shape should maintain the L-shaped cutout at the top right corner throughout the expansion process. The background opacity should also change from 40% to 70% to make the expanded bubble more visible and prominent on the screen.

This text continues with even more content to ensure that the height exceeds 120 points and triggers the expansion mechanism. We need to test multiple paragraphs and line breaks to verify that the layout handles various text lengths correctly.

Additional paragraph here to make absolutely sure we exceed the minimum height threshold. The responsive design should kick in automatically when this much text is present.
"""
        } else {
            return viewModel.bubbleText.isEmpty ? "Hello! 😊" : viewModel.bubbleText
        }
    }
    
    var body: some View {
        ZStack {
            // AR 画面（全屏）
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()
            
            // ViewFinder 取景框（全屏居中）- 展开时隐藏
            if !isBubbleExpanded {
                ViewFinder(
                    frameWidth: 280,
                    frameHeight: 360,
                    cornerLength: 30,
                    lineWidth: 3,
                    color: faceDetectionProvider.faceDetected ? .green : .white,
                    animating: !faceDetectionProvider.faceDetected
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
                        eyeSocketColor: .white.opacity(0.8),
                        pupilColor: .blue,
                        strokeWidth: 3.5,
                        showDecorations: true
                    )
                    .frame(width: 80, height: 93)  // 保持 63:73 的宽高比
                    .padding(.bottom, 120)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isBubbleExpanded)
            }
            
            // AI 气泡 overlay（始终显示）
            VStack {
                ZStack(alignment: .topTrailing) {
                    // 气泡框
                    ReactTextBarWithCircle(title: "", text: testText, isExpanded: $isBubbleExpanded)
                    
                    // LogoFrame 圆形叠加在气泡上
                    LogoFrame(
                        horizontalOffset: -6,   // 调整水平位置：正值向右，负值向左
                        verticalOffset: 0,     // 调整垂直位置：正值向下，负值向上
                        imageScale: 1.2        // 调整图像缩放：1.0为原始大小
                    )
                        .frame(height: 120)  // 与气泡高度一致
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .zIndex(isBubbleExpanded ? 1000 : 1)  // 展开时悬浮在所有UI之上
            
            // 调试面板（右上角）
            HStack {
                Spacer()
                DebugPanelView(viewModel: viewModel, isLongTextMode: $isLongTextMode)
            }
            
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
