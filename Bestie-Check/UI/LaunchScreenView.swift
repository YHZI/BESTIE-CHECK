import SwiftUI

/// A SwiftUI-based Launch Screen view that matches the loading overlay design
struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                
                // Show a subtle indicator that loading will start
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(width: 220)
                    
                    Text("Loading...")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}
