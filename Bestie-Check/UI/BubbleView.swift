//
//  BubbleView.swift
//  Bestie-Check
//
//  AI 回复气泡视图（类似 iMessage 风格）
//

import SwiftUI

struct BubbleView: View {
    let text: String
    let onClose: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 气泡内容
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemGray5))
                    )
                
                // 小尖角（指向下方）
                Triangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 12, height: 8)
                    .offset(x: 20, y: -1)
            }
            
            Spacer()
            
            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)  // 距离顶部安全区域
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Triangle Shape (气泡尖角)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    BubbleView(text: "Hello! I can see you're smiling! 😊", onClose: {})
        .background(Color.black)
}
