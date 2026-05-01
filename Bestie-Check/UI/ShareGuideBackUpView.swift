//
//  ShareGuideBackUpView.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 4/30/26.
//

import SwiftUI

/// A full-screen guide overlay shown before switching to the system camera.
/// Drop-in replacement for ShareGuideView — same interface, simpler UI.
struct ShareGuideBackUpView: View {

    // MARK: - Interface (mirrors ShareGuideView)
    var onBack: () -> Void
    var onCapture: (UIImage) -> Void
    var sharePreviewImage: UIImage? = nil
    var replyText: String = ""

    // MARK: - Private state
    @State private var isCameraPresented: Bool = false

    // The guide message
    private let guideText = "Next, we'll switch to the system camera. Please take a new photo, and then we'll use your new photo to help you create a new share."
    private let bubbleColor = Color(red: 0xEC/255, green: 0xEF/255, blue: 0xF3/255)

    var body: some View {
        ZStack {
            // ── Background: sharePreviewImage + dark overlay ─────────────
            Group {
                if let img = sharePreviewImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.black
                }
            }
            .ignoresSafeArea()

            Color.black.opacity(0.70)
                .ignoresSafeArea()

            // ── Bubble + LogoFrame ────────────────────────────────────────
            VStack {
                ZStack(alignment: .topTrailing) {

                    // Static bubble — height auto-sized to content
                    Text(guideText)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .padding(.leading, 18)
                        .padding(.trailing, CutoutPositionCalculator.cutoutWidth + 8)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            BubbleWithLCutout()
                                .fill(bubbleColor.opacity(0.55))
                        )

                    // LogoFrame — matches the full ZStack width; getPos() pins it to the cutout
                    LogoFrame(
                        horizontalOffset: -6,
                        verticalOffset: 0,
                        imageScale: 1.2,
                        isGlowing: false,
                        onTap: nil
                    )
                    // Give LogoFrame an explicit height equal to the cutout height so getPos() works
                    .frame(height: CutoutPositionCalculator.cutoutHeight * 2)
                    .allowsHitTesting(false)
                }
                .padding(.top, 140)
                .padding(.horizontal, 20)

                Spacer()
            }

            // ── Action buttons pinned to bottom ──────────────────────────
            VStack {
                Spacer()
                HStack(spacing: 16) {
                    // Back button
                    Button(action: onBack) {
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.vertical, 14)
                            .padding(.horizontal, 28)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    // Continue → open system camera
                    Button {
                        isCameraPresented = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Continue")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black.opacity(0.85))
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black.opacity(0.75))
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 28)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 52)
                .padding(.horizontal, 20)
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            ShareCameraPicker { image in
                isCameraPresented = false
                if let image {
                    onCapture(image)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Preview
#Preview {
    ShareGuideBackUpView(
        onBack: {},
        onCapture: { _ in }
    )
}
