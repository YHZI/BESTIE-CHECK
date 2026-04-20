import SwiftUI
import UIKit

struct ShareTemplateSelectionView: View {
    let replyText: String
    let preCapturedImage: UIImage?
    @Binding var composedImage: UIImage?

    var onPickTemplate: (UIImage) -> Void
    var onNewPhoto: (UIImage) -> Void
    var onDismiss: () -> Void

    @State private var isRetakeCameraPresented: Bool = false
    @State private var previewImage: UIImage? = nil   // 本地预览，拍照后直接替换

    private var canShare: Bool {
        previewImage != nil && !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            // 实时相机背景
            CameraPreview()
                .ignoresSafeArea()
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
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
            // 始终从合成开始，不用原始照片作为占位
            if let img = composedImage {
                previewImage = img
            } else if let photo = preCapturedImage {
                let reply = replyText
                DispatchQueue.global(qos: .userInitiated).async {
                    let composed = makeShareImage(photo: photo, replyText: reply)
                    DispatchQueue.main.async { previewImage = composed }
                }
            }
        }
        .fullScreenCover(isPresented: $isRetakeCameraPresented) {
            ShareCameraPicker { image in
                isRetakeCameraPresented = false
                guard let image else { return }
                // 先立即显示原始照片
                previewImage = image
                // 后台重新构造 share item，完成后替换
                let reply = replyText
                DispatchQueue.global(qos: .userInitiated).async {
                    let composed = makeShareImage(photo: image, replyText: reply)
                    DispatchQueue.main.async {
                        previewImage = composed
                    }
                }
            }
            .ignoresSafeArea()
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
                            ProgressView()
                                .tint(.white)
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
                isRetakeCameraPresented = true
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
                guard let img = previewImage else { return }
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
