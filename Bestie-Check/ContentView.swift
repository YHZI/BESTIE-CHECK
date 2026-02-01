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
    
    var body: some View {
        ZStack {
            // AR 画面（全屏）
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()
            
            // AI 气泡 overlay
            if viewModel.isBubbleVisible {
                BubbleView(text: viewModel.bubbleText) {
                    viewModel.hideBubble()
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
        .previewDevice("iPhone 15 Pro")
}
