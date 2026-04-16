import SwiftUI

struct ShareActionButtons: View {
    
    var onSave: () -> Void
    var onRetake: () -> Void
    
    var body: some View {
        HStack(spacing: 60) {
            
            ActionItem(
                icon: "arrow.down",
                title: "Save to Photo",
                action: onSave
            )
            
            ActionItem(
                icon: "arrow.clockwise",
                title: "Retake a Photo",
                action: onRetake
            )
        }
    }
}

struct ActionItem: View {
    
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            
            Button(action: action) {
                ZStack {
                    
                    /// 👇 圆形背景（重点）
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 64, height: 64)
                    
                    /// 👇 icon
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            
            /// 👇 文字
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }
}
