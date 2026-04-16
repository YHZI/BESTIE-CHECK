import SwiftUI

struct FeedbackBubble: View {
    var body: some View {
        Text("Sample feedback text here.")
            .font(.system(size: 14))
            .foregroundColor(.white)
            .padding()
            .background(Color.white.opacity(0.25))
            .cornerRadius(12)
    }
}
