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
    @ObservedObject var faceDetectionProvider = FaceDetectionProvider.shared
    @ObservedObject private var streakStore = StreakStore.shared
    @Binding var isLongTextMode: Bool
    @Binding var showViewFinderScan: Bool
    @Binding var useRGBBackground: Bool
    @Binding var showFunFact: Bool
    @State private var isExpanded: Bool = false
    @State private var testText: String = ""
    @State private var byteCount: Int = 0
    @State private var shouldExpand: Bool = false
    @State private var previewShareImage: UIImage? = nil
    @State private var savedToPhotos: Bool = false
    @State private var showPreview = false
    @State private var previewImageForUI: UIImage?
    @State private var showLaunchScreen = false
    
    // FunFact 注入文本
    @State private var funFactTestText: String = ""

    // Streak debug: simulated day offset from "today" used for the next check-in.
    @State private var streakDayOffset: Int = 0
    @State private var streakDebugMessage: String = ""
    
    private func updateExpansionCheck(_ text: String) {
        byteCount = text.utf8.count
        shouldExpand = byteCount > 180
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isExpanded {
                // 折叠态：仅显示触发按钮
                Button(action: {
                    isExpanded = true
                }) {
                    HStack {
                        Image(systemName: "chevron.up")
                        Text("Debug Panel")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                }
            } else {
                expandedPanel
            }
        }
    }

    // MARK: - Expanded panel

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 顶部标题栏 + Done 按钮
            HStack {
                Text("Debug Panel")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Button(action: { isExpanded = false }) {
                    Text("Done")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.85))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    debugContent
                }
                .padding(.trailing, 2)
            }
            .frame(maxHeight: 520)
        }
        .padding(12)
        .frame(width: 280, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 4)
    }

    // MARK: - Debug content (was the original expanded block, no animation)

    @ViewBuilder
    private var debugContent: some View {
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

                    Divider()
                        .background(Color.white.opacity(0.3))

                    // FunFact Bubble 控制区域
                    VStack(alignment: .leading, spacing: 8) {
                        // 显示/隐藏按钮
                        Button(action: {
                            showFunFact.toggle()
                        }) {
                            HStack {
                                Image(systemName: "bubble.left.fill")
                                Text(showFunFact ? "Hide FunFact Bubble" : "Show FunFact Bubble")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(showFunFact ? Color.teal.opacity(0.9) : Color.teal.opacity(0.7))
                            .cornerRadius(6)
                        }
                        
                        // 文本注入区域
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Inject FunFact Text:")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                            
                            TextField("Enter test text...", text: $funFactTestText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(6)
                                .lineLimit(3...6)
                            
                            HStack(spacing: 8) {
                                // 注入按钮
                                Button(action: {
                                    viewModel.funFactText = funFactTestText
                                    if !showFunFact {
                                        showFunFact = true
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "syringe.fill")
                                        Text("Inject")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(6)
                                    .background(Color.purple.opacity(0.8))
                                    .cornerRadius(6)
                                }
                                
                                // 清空按钮
                                Button(action: {
                                    funFactTestText = ""
                                    viewModel.funFactText = ""
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "trash.fill")
                                        Text("Clear")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(6)
                                    .background(Color.red.opacity(0.7))
                                    .cornerRadius(6)
                                }
                            }
                            
                            // 快速填充预设文本
                            HStack(spacing: 6) {
                                Button("Short") {
                                    funFactTestText = "This is a short test message."
                                }
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.6))
                                .cornerRadius(4)
                                
                                Button("Medium") {
                                    funFactTestText = "Your eyebrow raise is 78% — you look naturally expressive today! Keep it up! ✨"
                                }
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.6))
                                .cornerRadius(4)
                                
                                Button("Long") {
                                    funFactTestText = "Your eyebrow raise is 78% — you look naturally expressive today! This is a longer text to test the expand/collapse feature. It should trigger the expand button when displayed. Keep practicing your expressions! ✨🎉"
                                }
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.6))
                                .cornerRadius(4)
                            }
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                    }

                    Divider()
                        .background(Color.white.opacity(0.3))

                    streakDebugSection
    }

    // MARK: - Streak debug section

    @ViewBuilder
    private var streakDebugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Streak Debug")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }

            // 当前状态摘要
            VStack(alignment: .leading, spacing: 2) {
                Text("Current: \(streakStore.currentStreak)   Longest: \(streakStore.longestStreak)   ❄️ \(streakStore.freezeCount)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.9))
                Text("Today checked in: \(streakStore.checkedInToday ? "YES" : "NO")")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text("Sim offset: +\(streakDayOffset) day(s)  →  target = today+\(streakDayOffset)")
                    .font(.caption2)
                    .foregroundColor(.cyan.opacity(0.9))
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .cornerRadius(6)

            // 第一行：签到 / 跳过一天
            HStack(spacing: 6) {
                Button(action: {
                    #if DEBUG
                    let outcome = streakStore.debugCheckIn(daysFromNow: streakDayOffset)
                    switch outcome {
                    case .alreadyCheckedInToday:
                        streakDebugMessage = "Already checked in for that day."
                    case .checkedIn(let streak, let earned, let used, let first):
                        streakDebugMessage = "✓ Check-in. streak=\(streak)\(used ? " (freeze used)" : "")\(earned > 0 ? " +1 ❄️" : "")\(first ? " (first ever)" : "")"
                    }
                    #endif
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Check In Day +\(streakDayOffset)")
                    }
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.green.opacity(0.75))
                    .cornerRadius(6)
                }

                Button(action: {
                    streakDayOffset += 1
                    streakDebugMessage = "Skipped 1 day. Next check-in will be at +\(streakDayOffset)."
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "forward.fill")
                        Text("Skip 1 Day")
                    }
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.orange.opacity(0.75))
                    .cornerRadius(6)
                }
            }

            // 第二行：offset 控制 / 重置
            HStack(spacing: 6) {
                Button(action: {
                    streakDayOffset = max(0, streakDayOffset - 1)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "minus.circle")
                        Text("Offset -1")
                    }
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.gray.opacity(0.65))
                    .cornerRadius(6)
                }

                Button(action: {
                    streakDayOffset = 0
                    streakDebugMessage = "Offset reset to 0."
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Offset")
                    }
                    .font(.caption2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.blue.opacity(0.65))
                    .cornerRadius(6)
                }
            }

            // 危险操作：清空所有 streak 数据
            Button(action: {
                #if DEBUG
                streakStore.debugResetAll()
                streakDayOffset = 0
                streakDebugMessage = "All streak data wiped."
                #endif
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                    Text("Wipe All Streak Data")
                }
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(6)
                .background(Color.red.opacity(0.7))
                .cornerRadius(6)
            }

            if !streakDebugMessage.isEmpty {
                Text(streakDebugMessage)
                    .font(.caption2)
                    .foregroundColor(.yellow)
                    .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.4))
        .cornerRadius(8)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isLongTextMode = false
        @State private var showViewFinderScan = false
        @State private var useRGBBackground = false
        @State private var showFunFact = false

        var body: some View {
            DebugPanelView(
                viewModel: FaceMeshAssistantViewModel(),
                isLongTextMode: $isLongTextMode,
                showViewFinderScan: $showViewFinderScan,
                useRGBBackground: $useRGBBackground,
                showFunFact: $showFunFact
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

