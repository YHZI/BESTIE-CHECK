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
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 设置 ARView
        arView.automaticallyConfigureSession = false
        
        // 传递给 ViewModel 以启动 ARSession
        viewModel.setupARSession(arView: arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 更新时不需要操作
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        // 清理资源（如果需要）
    }
}
