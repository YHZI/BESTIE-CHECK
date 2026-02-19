//
//  DebugPanelView.swift
//  Bestie-Check
//
//  调试面板：FPS、节流设置等
//

import SwiftUI
import Combine

struct DebugPanelView: View {
    @ObservedObject var viewModel: FaceMeshAssistantViewModel
    @ObservedObject var faceDetectionProvider = FaceDetectionProvider.shared  // 人脸检测状态
    @Binding var isLongTextMode: Bool  // 添加 Binding 参数
    @Binding var showViewFinderScan: Bool  // ViewFinder 扫描线开关
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 折叠/展开按钮
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    Text("Debug Panel")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // FPS / 节流间隔
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Throttle Interval: \(viewModel.throttleIntervalMs)ms")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.throttleIntervalMs) },
                                set: { viewModel.throttleIntervalMs = Int($0) }
                            ),
                            in: 100...1000,
                            step: 50
                        )
                        .tint(.white)
                        
                        Text("≈ \(1000 / max(viewModel.throttleIntervalMs, 1)) fps")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // 上传整图开关
                    Toggle("Upload Full Image", isOn: $viewModel.uploadFullImage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .tint(.blue)
                    
                    // 显示无脸提示开关
                    Toggle("Show 'No Face' Message", isOn: $viewModel.showNoFaceMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .tint(.blue)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // 手动触发按钮
                    Button(action: {
                        viewModel.triggerManualAnalysis()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Manual Analysis")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(6)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // 切换长/短文本按钮
                    Button(action: {
                        withAnimation {
                            isLongTextMode.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: isLongTextMode ? "text.alignleft" : "text.aligncenter")
                            Text(isLongTextMode ? "Long Text Mode" : "Short Text Mode")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(isLongTextMode ? Color.orange.opacity(0.7) : Color.green.opacity(0.7))
                        .cornerRadius(6)
                    }
                    
                    // ViewFinder 扫描线按钮
                    Button(action: {
                        withAnimation {
                            showViewFinderScan.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: showViewFinderScan ? "eye.fill" : "eye.slash.fill")
                            Text("ViewFinder_Scan")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(showViewFinderScan ? Color.purple.opacity(0.7) : Color.gray.opacity(0.7))
                        .cornerRadius(6)
                    }
                    
                    // FaceDetected 手动切换按钮（用于测试）
                    Button(action: {
                        withAnimation {
                            faceDetectionProvider.updateFaceDetection(detected: !faceDetectionProvider.faceDetected)
                        }
                    }) {
                        HStack {
                            Image(systemName: faceDetectionProvider.faceDetected ? "face.smiling.fill" : "face.dashed.fill")
                            Text("FaceDetected")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(faceDetectionProvider.faceDetected ? Color.green.opacity(0.7) : Color.red.opacity(0.7))
                        .cornerRadius(6)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.trailing, 16)
        .padding(.top, 60)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isLongTextMode = false
        @State private var showViewFinderScan = false
        
        var body: some View {
            DebugPanelView(
                viewModel: FaceMeshAssistantViewModel(), 
                isLongTextMode: $isLongTextMode,
                showViewFinderScan: $showViewFinderScan
            )
                .background(Color.black)
        }
    }
    
    return PreviewWrapper()
}
