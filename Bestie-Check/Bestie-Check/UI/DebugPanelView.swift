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
    DebugPanelView(viewModel: FaceMeshAssistantViewModel())
        .background(Color.black)
}
