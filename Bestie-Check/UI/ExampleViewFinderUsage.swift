//
//  ExampleViewFinderUsage.swift
//  Bestie-Check
//
//  ViewFinder 组件集成示例
//

import SwiftUI

// MARK: - 示例 1: 基础使用
struct BasicViewFinderExample: View {
    var body: some View {
        ZStack {
            // 模拟相机背景
            Color.black.ignoresSafeArea()
            
            // ViewFinder 取景框
            ViewFinder(
                frameWidth: 280,
                frameHeight: 360,
                cornerLength: 30,
                lineWidth: 3,
                color: .white,
                animating: false
            )
        }
    }
}

// MARK: - 示例 2: 带扫描线动画
struct AnimatedViewFinderExample: View {
    var body: some View {
        ZStack {
            // 模拟相机背景
            Color.black.ignoresSafeArea()
            
            // ViewFinder 取景框（带扫描线）
            ViewFinder(
                frameWidth: 280,
                frameHeight: 360,
                cornerLength: 30,
                lineWidth: 3,
                color: .green,
                animating: true  // 启用扫描线动画
            )
            
            // 提示文字
            VStack {
                Spacer()
                Text("请将脸部对准取景框")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - 示例 3: 动态状态控制
struct DynamicViewFinderExample: View {
    @State private var isScanning = false
    @State private var faceDetected = false
    
    var currentColor: Color {
        if faceDetected {
            return .green  // 检测到人脸：绿色
        } else if isScanning {
            return .yellow  // 正在扫描：黄色
        } else {
            return .white  // 待机状态：白色
        }
    }
    
    var body: some View {
        ZStack {
            // 模拟相机背景
            Color.black.ignoresSafeArea()
            
            // ViewFinder 取景框
            ViewFinder(
                frameWidth: 280,
                frameHeight: 360,
                cornerLength: 30,
                lineWidth: 3,
                color: currentColor,
                animating: isScanning && !faceDetected
            )
            .animation(.easeInOut(duration: 0.3), value: currentColor)
            
            // 控制按钮
            VStack {
                Spacer()
                
                HStack(spacing: 20) {
                    Button("开始扫描") {
                        isScanning = true
                    }
                    .buttonStyle(ControlButtonStyle())
                    
                    Button("检测到人脸") {
                        faceDetected = true
                    }
                    .buttonStyle(ControlButtonStyle())
                    
                    Button("重置") {
                        isScanning = false
                        faceDetected = false
                    }
                    .buttonStyle(ControlButtonStyle())
                }
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - 示例 4: 与 ARView 集成
struct ARViewFinderExample: View {
    @StateObject private var viewModel = FaceMeshAssistantViewModel()
    
    // 使用人脸检测接口（默认返回 false）
    private let faceDetectionProvider: FaceDetectionProvider = DefaultFaceDetectionProvider()
    
    var body: some View {
        ZStack {
            // AR 相机画面
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()
            
            // ViewFinder 取景框
            ViewFinder(
                frameWidth: 280,
                frameHeight: 360,
                cornerLength: 30,
                lineWidth: 3,
                color: faceDetectionProvider.faceDetected ? .green : .white,
                animating: !faceDetectionProvider.faceDetected
            )
            
            // AI 气泡 overlay
            if viewModel.isBubbleVisible {
                VStack {
                    ZStack(alignment: .topTrailing) {
                        ReactTextBarWithCircle(text: viewModel.bubbleText)
                        LogoFrame()
                            .frame(height: 120)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - 辅助样式
struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.8))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Previews
#Preview("基础使用") {
    BasicViewFinderExample()
}

#Preview("带扫描线") {
    AnimatedViewFinderExample()
}

#Preview("动态状态") {
    DynamicViewFinderExample()
}
