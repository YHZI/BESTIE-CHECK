import SwiftUI
import AVFoundation
import Combine

// MARK: - AVFoundation Capture Session

private final class GuideShootSession: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    var onPhoto: ((UIImage) -> Void)?

    override init() {
        super.init()
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let input  = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()
    }

    func start() { DispatchQueue.global(qos: .userInitiated).async { [self] in if !session.isRunning { session.startRunning() } } }
    func stop()  { DispatchQueue.global(qos: .userInitiated).async { [self] in if  session.isRunning { session.stopRunning()  } } }
    func shoot() { photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self) }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let raw  = UIImage(data: data),
              let cg   = raw.cgImage else { return }
        let img = UIImage(cgImage: cg, scale: raw.scale, orientation: .leftMirrored)
        DispatchQueue.main.async { self.onPhoto?(img) }
    }
}

// MARK: - Live Camera UIViewRepresentable

private struct LiveCameraView: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> _V {
        let v = _V()
        v.pl.session      = session
        v.pl.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ v: _V, context: Context) {}
    class _V: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var pl: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - ShareGuideView

struct ShareGuideView: View {
    var onBack: () -> Void
    var onCapture: (UIImage) -> Void
    var sharePreviewImage: UIImage? = nil
    var replyText: String = ""

    @StateObject private var cam = GuideShootSession()

    private enum Phase { case animating, live, preview }
    @State private var phase: Phase = .animating

    @State private var cardScale: CGFloat = 0.62
    @State private var photoOpacity:    Double  = 1
    @State private var borderOpacity:   Double  = 1
    @State private var feedbackOpacity: Double  = 1
    @State private var cameraOpacity:   Double  = 0
    @State private var controlsOpacity: Double  = 0
    @State private var controlsOffset:  CGFloat = 110
    @State private var capturedImage:   UIImage? = nil
    @State private var flashOpacity:    Double  = 0

    // Independent phone-ratio colored border
    @State private var borderW:  CGFloat = 0
    @State private var borderH:  CGFloat = 0
    @State private var borderCR: CGFloat = 0

    private let boxAnchor  = UnitPoint(x: 0.5, y: 0.56)
    private let fullScale: CGFloat = 1.0 / 0.82

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let cardW = W * 0.62
            let cardH = H * 0.62

            ZStack(alignment: .center) {
                Color.black.ignoresSafeArea()

                // 1. Live camera
                LiveCameraView(session: cam.session)
                    .ignoresSafeArea()
                    .scaleEffect(x: -1)
                    .opacity(cameraOpacity)

                // 2. Expanding card — white background + header + feedback only (no colored border)
                if phase == .animating {
                    expandingCard(W: W, H: H, cardW: cardW, cardH: cardH)
                        .transition(.identity)
                }

                // 3. Independent phone-ratio colored border + photo — single component, frame animated
                if phase == .animating {
                    ZStack(alignment: .bottom) {
                        // Photo fill — strictly inside the border frame
                        if let img = sharePreviewImage {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: borderW, height: borderH)
                                .clipped()
                        } else {
                            Color.black.opacity(0.55)
                                .frame(width: borderW, height: borderH)
                        }

                        // Feedback bubble anchored to bottom of the box
                        feedbackBubble(boxW: borderW)
                            .padding(.bottom, 14)
                            .opacity(feedbackOpacity)
                    }
                    .frame(width: borderW, height: borderH)
                    .clipShape(RoundedRectangle(cornerRadius: borderCR))
                    .opacity(photoOpacity)
                    .overlay(
                        RoundedRectangle(cornerRadius: borderCR)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0x69/255.0, green: 0xAC/255.0, blue: 0x14/255.0),
                                        Color(red: 0x49/255.0, green: 0x3D/255.0, blue: 0x89/255.0),
                                        Color(red: 0xF8/255.0, green: 0x4C/255.0, blue: 0x4C/255.0),
                                        Color(red: 0x69/255.0, green: 0xAC/255.0, blue: 0x14/255.0),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .opacity(borderOpacity)
                    )
                    .transition(.identity)
                }

                // 4. Camera controls
                if phase == .live {
                    VStack {
                        Spacer()
                        cameraControls
                            .opacity(controlsOpacity)
                            .offset(y: controlsOffset)
                    }
                    .transition(.identity)
                }

                // 5. Capture review
                if phase == .preview, let img = capturedImage {
                    captureReview(img: img, W: W, H: H)
                        .transition(.opacity)
                }

                // 6. Shutter flash
                Color.white.ignoresSafeArea()
                    .opacity(flashOpacity)
                    .allowsHitTesting(false)
            }
            .onAppear {
                // Photo box apparent size at initial cardScale 0.62
                // boxW = W * 0.94, boxH = boxW * (H/W) → same aspect ratio as screen
                let boxW   = W * 0.94
                let boxH   = boxW * (H / W)
                let initW  = boxW  * 0.62
                let initH  = boxH  * 0.62
                let initCR = boxW  * 0.08 * 0.62
                borderW  = initW
                borderH  = initH
                borderCR = initCR

                cam.start()
                cam.onPhoto = handlePhoto
                startEntryAnimation(W: W, H: H)
            }
        }
        .ignoresSafeArea()
        .onDisappear { cam.stop() }
    }

    // MARK: - Expanding Card (no colored border — only white bg + header + feedback)

    @ViewBuilder
    private func expandingCard(W: CGFloat, H: CGFloat,
                                cardW: CGFloat, cardH: CGFloat) -> some View {
        let headerFrac: CGFloat = 0.13
        let headerH = H * headerFrac

        ZStack(alignment: .top) {
            Color.white

            brandHeader(w: W, headerH: headerH)
                .opacity(borderOpacity)
        }
        .frame(width: W, height: H)
        .scaleEffect(cardScale, anchor: boxAnchor)
    }

    // ── Brand header sub-view ──────────────────────────────────────────────
    @ViewBuilder
    private func brandHeader(w: CGFloat, headerH: CGFloat) -> some View {
        let logoSize: CGFloat = headerH * 0.55
        HStack(spacing: logoSize * 0.22) {
            if let logo = UIImage(named: "GoshshaIcon") {
                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: logoSize)
            }
            Text("GOSHSHA")
                .font(.system(size: headerH * 0.28, weight: .bold, design: .default))
                .foregroundStyle(Color.black.opacity(0.85))
        }
        .frame(width: w, height: headerH, alignment: .center)
    }

    // ── Feedback bubble ────────────────────────────────────────────────────
    @ViewBuilder
    private func feedbackBubble(boxW: CGFloat) -> some View {
        let words = replyText.split(separator: " ")
        if !words.isEmpty {
            let preview = words.prefix(20).joined(separator: " ")
                        + (words.count > 20 ? "…" : "")
            Text(preview)
                .font(.system(size: max(boxW * 0.038, 11)))
                .foregroundStyle(.black.opacity(0.8))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: boxW - 28, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // feedbackBubble (no-arg) kept for body usage
    @ViewBuilder
    private var feedbackBubble: some View {
        feedbackBubble(boxW: 220)
    }

    // MARK: - Camera Controls

    private var cameraControls: some View {
        HStack(spacing: 0) {
            camButton(icon: "xmark", label: "Cancel", action: onBack)
                .frame(maxWidth: .infinity)

            Button { cam.shoot() } label: {
                ZStack {
                    Circle().fill(Color.white).frame(width: 72, height: 72)
                    Circle().stroke(Color.white.opacity(0.45), lineWidth: 4).frame(width: 86, height: 86)
                }
            }
            .frame(maxWidth: .infinity)

            camButton(icon: "arrow.counterclockwise", label: "Retake", action: {})
                .frame(maxWidth: .infinity)
                .opacity(0.28)
                .disabled(true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 44)
    }

    // MARK: - Capture Review

    @ViewBuilder
    private func captureReview(img: UIImage, W: CGFloat, H: CGFloat) -> some View {
        ZStack {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: W, height: H)
                .clipped()
                .ignoresSafeArea()

            VStack {
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 200)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                HStack(spacing: 0) {
                    camButton(icon: "arrow.counterclockwise", label: "Retake") {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            capturedImage = nil
                            phase = .live
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Button { onCapture(img) } label: {
                        Text("Use Photo")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)

                    camButton(icon: "xmark", label: "Cancel", action: onBack)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 44)
            }
        }
    }

    // MARK: - Reusable Button

    @ViewBuilder
    private func camButton(icon: String, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }

    // MARK: - Capture Handler

    private func handlePhoto(_ img: UIImage) {
        capturedImage = img
        withAnimation(.easeOut(duration: 0.07)) { flashOpacity = 0.95 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            withAnimation(.easeIn(duration: 0.20)) { flashOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.easeInOut(duration: 0.28)) { phase = .preview }
            }
        }
    }

    // MARK: - Entry Animation

    private func startEntryAnimation(W: CGFloat, H: CGFloat) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // ① White card scales up (chrome pushed off edges)
            withAnimation(.spring(response: 1.08, dampingFraction: 0.88)) {
                cardScale = fullScale
            }

            // ② Colored border expands from photo-box apparent size → full W×H
            //    Uses the same spring so it tracks the card exactly.
            //    Corner radius also animates to 0 as border reaches screen edges.
            withAnimation(.spring(response: 1.08, dampingFraction: 0.88)) {
                borderW  = W
                borderH  = H
                borderCR = 0
            }

            // ③ White card fades out after border is large enough (~60% expansion)
            withAnimation(.easeIn(duration: 0.45).delay(0.55)) {
                borderOpacity   = 0   // fades the card chrome + colored border together
                feedbackOpacity = 0
            }

            // ④ Cross-dissolve dark placeholder → live camera
            withAnimation(.easeInOut(duration: 0.66).delay(0.65)) {
                photoOpacity  = 0
                cameraOpacity = 1
            }

            // ⑤ Controls slide up
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.60) {
                phase = .live
                withAnimation(.spring(response: 0.72, dampingFraction: 0.76)) {
                    controlsOpacity = 1
                    controlsOffset  = 0
                }
            }
        }
    }
}

#Preview {
    ShareGuideView(
        onBack: {},
        onCapture: { _ in },
        sharePreviewImage: nil,
        replyText: "Try a warmer lip shade — it would complement your undertone beautifully!"
    )
}
