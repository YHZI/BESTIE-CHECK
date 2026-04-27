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
    @Binding var useRGBBackground: Bool  // 背景模式开关
    @State private var isExpanded: Bool = false
    @State private var testText: String = ""
    @State private var byteCount: Int = 0
    @State private var shouldExpand: Bool = false
    @State private var previewShareImage: UIImage? = nil
    @State private var savedToPhotos: Bool = false
    @State private var showPreview = false
    @State private var previewImageForUI: UIImage?
    @State private var showLaunchScreen = false
    
    private func updateExpansionCheck(_ text: String) {
        byteCount = text.utf8.count
        shouldExpand = byteCount > 180
    }
    
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
                    
                    // RGB 背景切换按钮
                    Button(action: {
                        withAnimation {
                            useRGBBackground.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: useRGBBackground ? "paintpalette.fill" : "camera.fill")
                            Text(useRGBBackground ? "RGB Background" : "Camera Background")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(useRGBBackground ? Color.pink.opacity(0.7) : Color.cyan.opacity(0.7))
                        .cornerRadius(6)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // 气泡测试输入框
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bubble Inject Test")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        // 文本输入框
                        TextEditor(text: $testText)
                            .frame(height: 60)
                            .padding(6)
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(6)
                            .font(.system(size: 12))
                            .onChange(of: testText) { oldValue, newValue in
                                updateExpansionCheck(newValue)
                            }
                        
                        // 显示字节数（仅参考）
                        HStack(spacing: 8) {
                            Text("\(byteCount) bytes")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                Text("Inject → Expand")
                            }
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.6))
                            .cornerRadius(4)
                        }
                        
                        // 快捷测试按钮
                        HStack(spacing: 6) {
                            Button("Clear") {
                                testText = ""
                            }
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.6))
                            .cornerRadius(4)
                            
                            Button("180B") {
                                testText = String(repeating: "a", count: 180)
                            }
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.6))
                            .cornerRadius(4)
                            
                            Button("181B") {
                                testText = String(repeating: "a", count: 181)
                            }
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.6))
                            .cornerRadius(4)
                            
                            Button("Emoji") {
                                testText = "Hello! 😊👍🎉🌟✨💖🚀🔥💯🎨"
                            }
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.6))
                            .cornerRadius(4)
                        }
                        
                        // 注入到气泡按钮
                        Button(action: {
                            viewModel.injectTestText(testText, autoHide: false, isAIResponse: true)
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Inject to Bubble")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(6)
                        }
                        .disabled(testText.isEmpty)
                        .opacity(testText.isEmpty ? 0.5 : 1.0)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
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
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Launch Loading Screen 预览按钮
                    Button(action: {
                        showLaunchScreen = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Preview Launch Screen")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.indigo.opacity(0.7))
                        .cornerRadius(6)
                    }
                    .fullScreenCover(isPresented: $showLaunchScreen) {
                        LaunchLoadingContainerView()
                    }
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isLongTextMode = false
        @State private var showViewFinderScan = false
        @State private var useRGBBackground = false
        
        var body: some View {
            DebugPanelView(
                viewModel: FaceMeshAssistantViewModel(),
                isLongTextMode: $isLongTextMode,
                showViewFinderScan: $showViewFinderScan,
                useRGBBackground: $useRGBBackground
            )
            .background(Color.black)
        }
    }
    
    return PreviewWrapper()
}

// MARK: - Helpers
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

