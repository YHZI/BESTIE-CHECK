import SwiftUI

/// Placeholder guide page inserted into the share flow.
/// Flow requirement (scaffold):
/// user selfie -> guide page -> app auto photo
///
/// NOTE: This page is intentionally blank. A teammate will add real content later.
struct ShareGuidePlaceholderView: View {
    var onBack: () -> Void
    var onNext: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            // Placeholder content area (intentionally blank)
            Color.clear

            VStack {
                HStack {
                    BackButton(diameter: 22) {
                        onBack()
                    }
                    .padding(.leading, 24)
                    .padding(.top, 16)

                    Spacer()

                    Button(action: onNext) {
                        Text("Next")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Capsule())
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    ShareGuidePlaceholderView(onBack: {}, onNext: {})
}

