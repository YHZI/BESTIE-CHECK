import SwiftUI

/// Launch loading container with real resource loading progress
struct LaunchLoadingContainerView: View {
    @StateObject private var viewModel = FaceMeshAssistantViewModel()
    @ObservedObject private var preloader = ResourcePreloader.shared

    @State private var contentDidAppear: Bool = false
    @State private var isLoadingVisible: Bool = true
    @State private var contentOpacity: Double = 0
    @State private var displayProgress: Double = 0

    var body: some View {
        ZStack {
            // Build the real app view so we can detect readiness via onAppear.
            ContentView(viewModel: viewModel, onAppReady: {
                contentDidAppear = true
            })
            .opacity(contentOpacity)
            .allowsHitTesting(!isLoadingVisible)

            if isLoadingVisible {
                LaunchLoadingOverlay(
                    progress: displayProgress,
                    status: preloader.loadingStatus
                )
                .transition(.opacity)
            }
        }
        .task {
            await runProgressSequence()
        }
    }

    private func setProgress(_ value: Double) {
        withAnimation(.easeInOut(duration: 0.45)) {
            displayProgress = min(max(value, 0), 100)
        }
    }

    private func runProgressSequence() async {
        // 实时监听 preloader 进度
        while !preloader.isReady || !contentDidAppear {
            // 使用真实的预加载进度（0-80%）
            let realProgress = preloader.progress * 0.8
            setProgress(realProgress)
            
            // 如果预加载完成但内容还没 appear，显示 80-95%
            if preloader.isReady && !contentDidAppear {
                setProgress(Double.random(in: 80...95))
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms 更新一次
        }

        // 全部就绪，跳到 100%
        setProgress(100)
        try? await Task.sleep(nanoseconds: 350_000_000)
        
        // Pre-render ContentView before fading out overlay
        withAnimation(.easeInOut(duration: 0.2)) {
            contentOpacity = 1.0
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.easeInOut(duration: 0.25)) {
            isLoadingVisible = false
        }
    }
}

private struct LaunchLoadingOverlay: View {
    var progress: Double
    var status: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)

                VStack(spacing: 10) {
                    ProgressView(value: progress, total: 100)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 220)

                    Text("\(Int(progress))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    
                    Text(status)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
    }
}

#Preview {
    LaunchLoadingContainerView()
}

