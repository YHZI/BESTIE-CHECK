import SwiftUI
import UIKit

enum ShareReplyTemplate: String, CaseIterable, Identifiable {
    case original = "Original"
    case bestie = "Bestie"
    case short = "Short"

    var id: String { rawValue }

    func apply(to replyText: String) -> String {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .original:
            return trimmed
        case .bestie:
            return "Bestie check: \(trimmed)"
        case .short:
            let words = trimmed.split(separator: " ").prefix(12)
            let condensed = words.joined(separator: " ")
            return condensed + (trimmed.split(separator: " ").count > 12 ? "…" : "")
        }
    }
}

struct ShareTemplateSelectionView: View {
    let replyText: String
    let preCapturedImage: UIImage?
    let manualSelfie: UIImage?

    var onPickTemplate: (UIImage) -> Void
    var onRetake: () -> Void
    var onDismiss: () -> Void

    @State private var selectedTemplate: ShareReplyTemplate = .original

    private var effectiveImage: UIImage? {
        manualSelfie ?? preCapturedImage
    }

    private var canShare: Bool {
        effectiveImage != nil && !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                header

                ScrollView {
                    VStack(spacing: 16) {
                        previewCard
                        templatePicker
                        actions
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
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
            Text("Choose a share template")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(manualSelfie == nil ? "Auto photo (AI image)" : "Selfie (retake)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            Group {
                if let img = effectiveImage, !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let composed = makeShareImage(photo: img, replyText: selectedTemplate.apply(to: replyText))
                    Image(uiImage: composed)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                } else if let img = effectiveImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 260)
                        .overlay(
                            VStack(spacing: 10) {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("No pre-captured photo yet.\nYou can retake a selfie.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 16)
                        )
                }
            }

            Text("AI reply preview")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            Text(selectedTemplate.apply(to: replyText).isEmpty ? "No AI reply" : selectedTemplate.apply(to: replyText))
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private var templatePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Templates")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 10) {
                ForEach(ShareReplyTemplate.allCases) { tpl in
                    Button {
                        selectedTemplate = tpl
                    } label: {
                        Text(tpl.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selectedTemplate == tpl ? .black : .white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(selectedTemplate == tpl ? Color.white : Color.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onRetake) {
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
                guard let img = effectiveImage else { return }
                let composed = makeShareImage(photo: img, replyText: selectedTemplate.apply(to: replyText))
                onPickTemplate(composed)
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
        manualSelfie: nil,
        onPickTemplate: { _ in },
        onRetake: {},
        onDismiss: {}
    )
}

