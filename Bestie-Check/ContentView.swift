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
    
    var body: some View {
        ZStack {
            // AR 画面（全屏）
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()
            
            // ViewFinder 取景框（全屏居中）
            ViewFinder(
                frameWidth: 280,
                frameHeight: 360,
                cornerLength: 30,
                lineWidth: 3,
                color: faceDetectionProvider.faceDetected ? .green : .white,
                animating: !faceDetectionProvider.faceDetected
            )
            
            // ARIcon 组件（放在 ViewFinder 下面）
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
            
            // AI 气泡 overlay
            if viewModel.isBubbleVisible {
                VStack {
                    ZStack(alignment: .topTrailing) {
                        // 气泡框
                        ReactTextBarWithCircle(text: viewModel.bubbleText)
                        
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
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isBubbleVisible)
            }
            
            // 调试面板（右上角）
            HStack {
                Spacer()
                DebugPanelView(viewModel: viewModel)
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
            
            // 测试按钮 - 手动触发气泡
            VStack {
                Spacer()
                Button(action: {
                    viewModel.triggerTestBubble()
                }) {
                    Text("Test Bubble")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding(.bottom, 50)
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
