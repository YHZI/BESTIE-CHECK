import SwiftUI

/// Launch loading container with a 4-step progress behavior:
/// 1) Random progress in 0...20
/// 2) Random progress in 60...70
/// 3) Random progress in 80...95
/// 4) When the app is detected ready, jump to 100 and enter the app
struct LaunchLoadingContainerView: View {
    @StateObject private var viewModel = FaceMeshAssistantViewModel()

    @State private var contentDidAppear: Bool = false
    @State private var isLoadingVisible: Bool = true
    @State private var contentOpacity: Double = 0
    @State private var progress: Double = 0

    var body: some View {
        ZStack {
            // Build the real app view so we can detect readiness via onAppear.
            ContentView(viewModel: viewModel, onAppReady: {
                contentDidAppear = true
            })
            .opacity(contentOpacity)
            .allowsHitTesting(!isLoadingVisible)

            if isLoadingVisible {
                LaunchLoadingOverlay(progress: progress)
                    .transition(.opacity)
            }
        }
        // Attach the task to the container (not the overlay) so it isn't cancelled
        // when isLoadingVisible flips to false and the overlay leaves the hierarchy.
        .task {
            await runProgressSequence()
        }
    }

    private func setProgress(_ value: Double) {
        withAnimation(.easeInOut(duration: 0.45)) {
            progress = min(max(value, 0), 100)
        }
    }

    private func random(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range)
    }

    private func runProgressSequence() async {
        // Step 1: 0...20
        setProgress(random(in: 0...20))
        try? await Task.sleep(nanoseconds: 600_000_000)

        // Step 2: 60...70
        setProgress(random(in: 60...70))
        try? await Task.sleep(nanoseconds: 650_000_000)

        // Step 3: 80...95
        setProgress(random(in: 80...95))

        // Step 4: wait until real content is ready, then go 100 and enter.
        while !contentDidAppear {
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        setProgress(100)
        try? await Task.sleep(nanoseconds: 350_000_000)
        // Pre-render ContentView before fading out overlay to avoid white flash
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
                }
            }
        }
    }
}

#Preview {
    LaunchLoadingContainerView()
}

