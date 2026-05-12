import SwiftUI

/// App flow phases: loading → login → main content
private enum AppPhase {
    case loading
    case login
    case mainApp
}

/// Launch loading container with real resource loading progress
struct LaunchLoadingContainerView: View {
    @StateObject private var viewModel = FaceMeshAssistantViewModel()
    @ObservedObject private var preloader = ResourcePreloader.shared

    @State private var contentDidAppear: Bool = false
    @State private var phase: AppPhase = .loading
    @State private var contentOpacity: Double = 0
    @State private var displayProgress: Double = 0

    var body: some View {
        ZStack {
            ContentView(viewModel: viewModel, onAppReady: {
                contentDidAppear = true
            })
            .opacity(contentOpacity)
            .allowsHitTesting(phase == .mainApp)

            if phase == .login {
                LoginView(
                    onSkip: { enterMainApp() },
                    onLogin: {
                        // TODO: Implement real auth flow
                        enterMainApp()
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }

            if phase == .loading {
                LaunchLoadingOverlay(
                    progress: displayProgress,
                    status: preloader.loadingStatus
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .task {
            await runProgressSequence()
        }
    }

    private func enterMainApp() {
        withAnimation(.easeInOut(duration: 0.2)) {
            contentOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = .mainApp
            }
        }
    }

    private func setProgress(_ value: Double) {
        withAnimation(.easeInOut(duration: 0.45)) {
            displayProgress = min(max(value, 0), 100)
        }
    }

    private func runProgressSequence() async {
        while !preloader.isReady || !contentDidAppear {
            let realProgress = preloader.progress * 0.8
            setProgress(realProgress)
            
            if preloader.isReady && !contentDidAppear {
                setProgress(Double.random(in: 80...95))
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        setProgress(100)
        try? await Task.sleep(nanoseconds: 350_000_000)

        withAnimation(.easeInOut(duration: 0.3)) {
            phase = .login
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

