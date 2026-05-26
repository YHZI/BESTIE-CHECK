//
//  component_ShareGuideBackUp.swift
//  Bestie-Check
//
//  Created by in4matx_inst on 5/3/26.
//  Share guide backup overlay component that can be stacked on top of other views.
//

import SwiftUI

/// A semi-transparent overlay component with bubble + buttons, designed to stack on top of camera preview.
/// Unlike fullScreenCover, this allows the underlying view to show through.
struct ShareGuideBackUpOverlay: View {

    // MARK: - Interface
    var onBack: () -> Void
    var onContinue: () -> Void

    // The guide message
    private let guideText = "Next, we'll switch to the system camera. Please take a new photo, and then we'll use your new photo to help you create a new share."
    private let bubbleColor = Color(red: 0xEC/255, green: 0xEF/255, blue: 0xF3/255)

    var body: some View {
        ZStack {
            // ── Semi-transparent dark overlay ─────────────────────────────
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

                    // LogoFrame in the cutout area
                    LogoFrame(
                        horizontalOffset: 0,
                        verticalOffset: 0,
                        imageScale: 0.72,
                        isGlowing: false,
                        onTap: nil
                    )
                    .frame(height: CutoutPositionCalculator.cutoutHeight * 2)
                    .allowsHitTesting(false)
                }
                .padding(.top, 160)
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

                    // Continue button
                    Button(action: onContinue) {
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
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        // Simulated camera preview background
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        ShareGuideBackUpOverlay(
            onBack: { print("Back tapped") },
            onContinue: { print("Continue tapped") }
        )
    }
}
