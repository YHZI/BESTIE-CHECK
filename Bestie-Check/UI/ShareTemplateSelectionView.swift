import SwiftUI
import UIKit

struct ShareTemplateSelectionView: View {
    let replyText: String
    let preCapturedImage: UIImage?
    @Binding var composedImage: UIImage?

    var onPickTemplate: (UIImage) -> Void
    var onNewPhoto: (UIImage) -> Void
    var onDismiss: () -> Void

    @State private var isGuidePresented: Bool = false
    @State private var previewImage: UIImage? = nil
    @State private var isShowingRetakeReminder: Bool = false

    // 总是允许分享——没有合成图时会在分享时临时生成白色图片
    private var canShare: Bool { true }

    var body: some View {
        ZStack {
            // 实时相机背景：保持在视图树中以避免重建，isActive=false 时暂停 session
            // 让位给相机 picker（避免两个 AVCaptureSession 争抢前置摄像头）
            CameraPreview(isActive: !isGuidePresented)
                .ignoresSafeArea()
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    retakeReminder
                        .padding(.horizontal, 20)
                        .padding(.top, 14)

                    previewCard
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
                actions
                    .padding(.horizontal, 20)
                    .padding(.bottom, UIScreen.main.bounds.height * 0.03)
                    .padding(.top, 12)
            }
        }
        .onAppear {
            if let img = composedImage {
                previewImage = img
            }
            // 没有图片时保持 previewImage = nil，显示 Composing... loading 状态
            // 白色图片只在实际分享时才会生成（不插入预览 UI）
        }
        .onChange(of: composedImage) { _, newValue in
            if let img = newValue { previewImage = img }
            // Retake "in progress" reminder ends once a composed image is ready.
            if newValue != nil, isShowingRetakeReminder {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isShowingRetakeReminder = false
                }
            }
        }
        .fullScreenCover(isPresented: $isGuidePresented) {
            ShareGuideBackUpView(
                onBack: { isGuidePresented = false },
                onCapture: { image in
                    isGuidePresented = false
                    previewImage = image
                    isShowingRetakeReminder = true
                    onNewPhoto(image)
                },
                sharePreviewImage: preCapturedImage,
                replyText: replyText
            )
            .ignoresSafeArea()
        }
    }

    private var retakeReminder: some View {
        Group {
            if isShowingRetakeReminder {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Retaking… We’re updating your share preview.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .transition(.opacity)
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }
            Spacer()
            Text("Share Preview")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var previewCard: some View {
        let screen = UIScreen.main.bounds
        let previewW = screen.width  * 0.62
        let previewH = screen.height * 0.62

        return Group {
            if let img = previewImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: previewW, height: previewH)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: previewW, height: previewH)
                    .overlay(
                        VStack(spacing: 10) {
                            ProgressView().tint(.white)
                            Text("Composing...")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                isGuidePresented = true
            } label: {
                HStack {
                    Image(systemName: "camera")
                    Text("Not satisfied? Take a selfie")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button {
                // 分享时只传真正的合成图片，如果没有则临时生成白色图片
                let img: UIImage
                if let composed = composedImage {
                    img = composed
                } else {
                    let screen = UIScreen.main
                    let ptWidth = screen.bounds.width
                    let ptHeight = screen.bounds.height
                    let renderScale = screen.scale
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = renderScale
                    format.opaque = true
                    img = UIGraphicsImageRenderer(size: CGSize(width: ptWidth, height: ptHeight), format: format).image { ctx in
                        UIColor.white.setFill()
                        ctx.fill(CGRect(origin: .zero, size: CGSize(width: ptWidth, height: ptHeight)))
                    }
                }
                onPickTemplate(img)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Continue to Share")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(canShare ? .black : .black.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canShare ? Color.white : Color.white.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canShare)
        }
    }
}

#Preview {
    ShareTemplateSelectionView(
        replyText: "Try a different lip color; the current tone is slightly cool for your undertone.",
        preCapturedImage: UIImage(systemName: "person.fill"),
        composedImage: .constant(nil),
        onPickTemplate: { _ in },
        onNewPhoto: { _ in },
        onDismiss: {}
    )
}
