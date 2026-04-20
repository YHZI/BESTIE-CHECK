//
//  ARViewContainer.swift
//  Bestie-Check
//
//  UIViewRepresentable 包装 ARView，供 SwiftUI 使用
//

import SwiftUI
import RealityKit
import ARKit
import Combine

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: FaceMeshAssistantViewModel
    @Binding var useRGBBackground: Bool
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 设置 ARView
        arView.automaticallyConfigureSession = false
        
        // 传递给 ViewModel 以启动 ARSession
        viewModel.setupARSession(arView: arView)
        
        // 保存 ARView 引用到 coordinator
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 根据 useRGBBackground 切换背景，仅在模式真正变化时才重新配置
        if useRGBBackground {
            if !context.coordinator.isShowingRGB {
                context.coordinator.isShowingRGB = true
                // 暂停 AR Session
                uiView.session.pause()
                // 启动 RGB 颜色循环动画
                context.coordinator.startRGBAnimation()
            }
        } else {
            if context.coordinator.isShowingRGB || !context.coordinator.arSessionStarted {
                context.coordinator.isShowingRGB = false
                context.coordinator.arSessionStarted = true
                // 停止 RGB 动画
                context.coordinator.stopRGBAnimation()
                // 恢复 AR Session（仅在切换时调用，避免每次 SwiftUI update 都重启）
                viewModel.setupARSession(arView: uiView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var arView: ARView?
        /// 防止 updateUIView 在每次 SwiftUI re-render 时重启 ARSession
        var arSessionStarted: Bool = false
        var isShowingRGB: Bool = false
        private var colorTimer: Timer?
        private var currentColorIndex: Int = 0
        private let rgbColors: [UIColor] = [
            UIColor.red,
            UIColor.green,
            UIColor.blue
        ]
        
        func startRGBAnimation() {
            guard let arView = arView else { return }
            
            // 停止之前的定时器
            stopRGBAnimation()
            
            // 设置初始颜色
            currentColorIndex = 0
            arView.environment.background = .color(rgbColors[currentColorIndex])
            
            // 每2秒切换一次颜色
            colorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                guard let self = self, let arView = self.arView else { return }
                
                // 切换到下一个颜色
                self.currentColorIndex = (self.currentColorIndex + 1) % self.rgbColors.count
                
                // 使用动画过渡
                UIView.animate(withDuration: 0.5) {
                    arView.environment.background = .color(self.rgbColors[self.currentColorIndex])
                }
            }
        }
        
        func stopRGBAnimation() {
            colorTimer?.invalidate()
            colorTimer = nil
        }
        
        deinit {
            stopRGBAnimation()
        }
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        // 清理资源
        coordinator.stopRGBAnimation()
    }
}
