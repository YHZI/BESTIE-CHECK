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
    @State private var previewImage: UIImage? = nil

    private var canShare: Bool {
        previewImage != nil && !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            // 实时相机背景：保持在视图树中以避免重建，isActive=false 时暂停 session
            // 让位给相机 picker（避免两个 AVCaptureSession 争抢前置摄像头）
            CameraPreview(isActive: !isRetakeCameraPresented)
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
        // composedImage 由 ShareFlowModifier 负责合成并更新，这里只需同步显示
        .onAppear {
            if let img = composedImage { previewImage = img }
        }
        .onChange(of: composedImage) { _, newValue in
            if let img = newValue { previewImage = img }
        }
        .fullScreenCover(isPresented: $isRetakeCameraPresented) {
            ShareCameraPicker { image in
                isRetakeCameraPresented = false
                guard let image else { return }
                // 立即显示原始照片作为占位
                previewImage = image
                // 通知 Modifier 重新合成（Modifier 持有 Task，可 cancel 旧任务）
                onNewPhoto(image)
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
            Button { isRetakeCameraPresented = true } label: {
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
