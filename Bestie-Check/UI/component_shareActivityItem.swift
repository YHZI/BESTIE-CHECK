//
//  component_shareActivityItem.swift
//  Bestie-Check
//
//  Share 功能封装：图片合成 + 相机拍照 + 系统分享面板
//

import SwiftUI
import UIKit
import CoreText

// MARK: - Share Activity Item (Compatibility)

/// Many third-party share extensions are flaky with in-memory `UIImage`.
/// Provide a temporary JPEG file URL for better interoperability.
final class ShareImageActivityItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let fileURL: URL

    init?(image: UIImage, preferredFileName: String = "GOSHSHA-Share") {
        self.image = image

        let dir = FileManager.default.temporaryDirectory
        let file = "\(preferredFileName)-\(UUID().uuidString).jpg"
        self.fileURL = dir.appendingPathComponent(file)

        super.init()

        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            return nil
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        // Keep "Copy" behavior consistent (pasteboard expects UIImage).
        if activityType == .copyToPasteboard {
            return image
        }
        return fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "public.jpeg"
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "GOSHSHA"
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        thumbnailImageForActivityType activityType: UIActivity.ActivityType?,
        suggestedSize size: CGSize
    ) -> UIImage? {
        image
    }
}

// MARK: - Font Loader

/// 从 Bundle 动态注册并返回自定义字体，失败时回退到系统字体
private func playwriteFont(size: CGFloat, weight: CGFloat = 700) -> UIFont {
    // 尝试直接用名称获取（已注册过）
    let familyName = "Playwrite IE"
    if let font = UIFont(name: familyName, size: size) {
        return font
    }

    // 未注册时从 Bundle 读取并注册
    if let url = Bundle.main.url(forResource: "PlaywriteIE-VariableFont_wght",
                                  withExtension: "ttf") {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        if let font = UIFont(name: familyName, size: size) {
            return font
        }
    }

    // 回退
    return UIFont.systemFont(ofSize: size, weight: .bold)
}

// MARK: - Share Image Composer

/// 将 AI 回复文字合成到照片上，生成可分享的图片
func makeShareImage(photo: UIImage, replyText: String) -> UIImage {

    // ── 1. Canvas 尺寸（设备屏幕比例，物理像素）──────────────────────────
    let screen      = UIScreen.main
    let ptWidth     = screen.bounds.width
    let ptHeight    = screen.bounds.height          // 真实屏幕比例
    let renderScale = screen.scale                  // @2x / @3x

    let format = UIGraphicsImageRendererFormat()
    format.scale = renderScale
    format.opaque = true

    let renderer = UIGraphicsImageRenderer(
        size: CGSize(width: ptWidth, height: ptHeight),
        format: format
    )

    return renderer.image { ctx in
        let cgCtx  = ctx.cgContext
        let ptSize = CGSize(width: ptWidth, height: ptHeight)
        let bounds = CGRect(origin: .zero, size: ptSize)

        // ── 2. 纯白实色底 ────────────────────────────────────────────────
        UIColor.white.setFill()
        ctx.fill(bounds)

        // ── 3. 品牌 header（Logo + "GOSHSHA"，水平居中）──────────────────
        let headerH:  CGFloat = ptSize.height * 0.13
        let logoSize: CGFloat = headerH * 0.70 * 1.10
        let brandGap: CGFloat = logoSize * 0.25
        let centerY:  CGFloat = headerH / 2 + headerH * 0.20

        let brandFont = playwriteFont(size: ptSize.height * 0.10 * 0.38)
        let brandText = "GOSHSHA" as NSString
        let brandAttrs: [NSAttributedString.Key: Any] = [
            .font: brandFont,
            .foregroundColor: UIColor.black.withAlphaComponent(0.85),
        ]
        let brandTextSize = brandText.size(withAttributes: brandAttrs)
        let totalW = logoSize + brandGap + brandTextSize.width
        let startX = (ptSize.width - totalW) / 2

        if let logoImage = UIImage(named: "GoshshaIcon") {
            let logoW = logoSize
            let logoH = logoSize * 1.31
            logoImage.draw(in: CGRect(x: startX, y: centerY - logoH / 2, width: logoW, height: logoH))
        }
        brandText.draw(
            in: CGRect(x: startX + logoSize + brandGap, y: centerY - brandTextSize.height / 2,
                       width: brandTextSize.width, height: brandTextSize.height),
            withAttributes: brandAttrs
        )

        // ── 4. 方框尺寸计算 ───────────────────────────────────────────────
        let boxPadding: CGFloat = ptSize.width  * 0.03
        let boxTop:     CGFloat = headerH + ptSize.height * 0.02
        let boxWidth:   CGFloat = ptSize.width  - boxPadding * 2
        let boxBottom:  CGFloat = ptSize.height - ptSize.height * 0.03
        let boxHeight:  CGFloat = boxBottom - boxTop
        let boxCorner:  CGFloat = boxWidth * 0.08
        let strokeW:    CGFloat = 3.0
        let boxRect = CGRect(x: boxPadding, y: boxTop, width: boxWidth, height: boxHeight)

        // ── 5. 用户照片（aspect-fill，clip 到圆角方框内部）────────────────
        let boxClipPath = UIBezierPath(roundedRect: boxRect, cornerRadius: boxCorner)
        cgCtx.saveGState()
        cgCtx.addPath(boxClipPath.cgPath)
        cgCtx.clip()

        let imgSize  = photo.size
        let imgScale = max(boxWidth  / max(imgSize.width,  1),
                           boxHeight / max(imgSize.height, 1))
        let drawW    = imgSize.width  * imgScale
        let drawH    = imgSize.height * imgScale
        photo.draw(in: CGRect(
            x: boxRect.minX + (boxWidth  - drawW) / 2,
            y: boxRect.minY + (boxHeight - drawH) / 2,
            width: drawW, height: drawH
        ))
        cgCtx.restoreGState()

        // ── 6. 渐变描边（三色循环 69AC14 → 493D89 → F84C4C）─────────────
        let strokePath = UIBezierPath(roundedRect: boxRect, cornerRadius: boxCorner)
        strokePath.lineWidth = strokeW

        cgCtx.saveGState()
        cgCtx.setLineWidth(strokeW)
        cgCtx.addPath(strokePath.cgPath)
        cgCtx.replacePathWithStrokedPath()
        cgCtx.clip()

        let c1 = UIColor(red: 0x69/255.0, green: 0xAC/255.0, blue: 0x14/255.0, alpha: 1)
        let c2 = UIColor(red: 0x49/255.0, green: 0x3D/255.0, blue: 0x89/255.0, alpha: 1)
        let c3 = UIColor(red: 0xF8/255.0, green: 0x4C/255.0, blue: 0x4C/255.0, alpha: 1)
        let colorSpace  = CGColorSpaceCreateDeviceRGB()
        let gradColors  = [c1.cgColor, c2.cgColor, c3.cgColor, c1.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 0.33, 0.66, 1.0]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: locations)!
        cgCtx.drawLinearGradient(gradient,
                                  start: CGPoint(x: boxRect.minX, y: boxRect.minY),
                                  end:   CGPoint(x: boxRect.maxX, y: boxRect.maxY),
                                  options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        cgCtx.restoreGState()

                // ── 7. 玻璃质感气泡（承载 AI 反馈，位于方框下半部分）─────────────
        // 截取前 25 个单词
        let words      = replyText.split(separator: " ").prefix(25)
        let shortReply = words.joined(separator: " ") + (replyText.split(separator: " ").count > 25 ? "…" : "")

        guard !shortReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let bubblePad:    CGFloat = boxWidth  * 0.05   // 气泡与方框内壁间距
        let bubbleW:      CGFloat = boxWidth  - bubblePad * 2
        let bubbleH:      CGFloat = boxHeight * 0.30   // 占方框高度 30%
        let bubbleCorner: CGFloat = boxCorner * 0.75
        let bubbleX:      CGFloat = boxRect.minX + bubblePad
        let bubbleY:      CGFloat = boxRect.maxY - bubblePad - bubbleH  // 紧贴方框底部
        let bubbleRect    = CGRect(x: bubbleX, y: bubbleY, width: bubbleW, height: bubbleH)
        let bubblePath    = UIBezierPath(roundedRect: bubbleRect, cornerRadius: bubbleCorner)

        cgCtx.saveGState()
        cgCtx.addPath(bubblePath.cgPath)
        cgCtx.clip()

        // 玻璃底层：白色半透明
        UIColor.white.withAlphaComponent(0.30).setFill()
        bubblePath.fill()

        // 玻璃光泽：顶部高光线性渐变
        let glassColors = [UIColor.white.withAlphaComponent(0.55).cgColor,
                           UIColor.white.withAlphaComponent(0.10).cgColor] as CFArray
        let glassGradient = CGGradient(colorsSpace: colorSpace,
                                       colors: glassColors,
                                       locations: [0.0, 1.0])!
        cgCtx.drawLinearGradient(glassGradient,
                                  start: CGPoint(x: bubbleRect.midX, y: bubbleRect.minY),
                                  end:   CGPoint(x: bubbleRect.midX, y: bubbleRect.maxY),
                                  options: [])

        cgCtx.restoreGState()

        // 玻璃边框：细白描边
        UIColor.white.withAlphaComponent(0.60).setStroke()
        bubblePath.lineWidth = 1.0
        bubblePath.stroke()

        // 气泡内文字
        let textPadH:  CGFloat = bubbleW * 0.06
        let textPadV:  CGFloat = bubbleH * 0.12
        let textRect   = bubbleRect.insetBy(dx: textPadH, dy: textPadV)

        let bubbleFont = UIFont.systemFont(ofSize: bubbleH * 0.13, weight: .regular)
        let paraStyle  = NSMutableParagraphStyle()
        paraStyle.lineSpacing    = bubbleH * 0.02
        paraStyle.alignment      = .left
        paraStyle.lineBreakMode  = .byWordWrapping

        let textAttrs: [NSAttributedString.Key: Any] = [
            .font:            bubbleFont,
            .foregroundColor: UIColor.black.withAlphaComponent(0.80),
            .paragraphStyle:  paraStyle
        ]
        (shortReply as NSString).draw(with: textRect,
                                      options: [.usesLineFragmentOrigin, .usesFontLeading],
                                      attributes: textAttrs,
                                      context: nil)
    }
}

// MARK: - Share Image Preview (Debug)

/// 测试用：用白色 60% 占位背景替代用户照片，直接生成分享图预览
/// 在 Debug Panel 中调用，无需相机
func makeShareImagePreview(replyText: String) -> UIImage {
    let screen      = UIScreen.main
    let ptWidth     = screen.bounds.width
    let ptHeight    = screen.bounds.height          // 真实屏幕比例
    let renderScale = screen.scale

    let format = UIGraphicsImageRendererFormat()
    format.scale = renderScale
    format.opaque = true

    let placeholder = UIGraphicsImageRenderer(
        size: CGSize(width: ptWidth, height: ptHeight),
        format: format
    ).image { ctx in
        UIColor.white.setFill()
        ctx.fill(CGRect(origin: .zero, size: CGSize(width: ptWidth, height: ptHeight)))
        UIColor.black.withAlphaComponent(0.08).setFill()
        ctx.fill(CGRect(origin: .zero, size: CGSize(width: ptWidth, height: ptHeight)))
    }
    return makeShareImage(photo: placeholder, replyText: replyText)
}

// MARK: - ShareFlow ViewModifier

/// 将完整的 share 流程（相机 → 合成 → 系统分享面板）作为 ViewModifier 挂载到任意 View
struct ShareFlowModifier: ViewModifier {
    @Binding var isPresented: Bool
    let replyText: String
    let preCapturedImage: UIImage?

    @State private var composedImage: UIImage? = nil

    private func recompose(with photo: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = makeShareImage(photo: photo, replyText: replyText)
            DispatchQueue.main.async { composedImage = result }
        }
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                ShareTemplateSelectionView(
                    replyText: replyText,
                    preCapturedImage: preCapturedImage,
                    composedImage: $composedImage,
                    onPickTemplate: { img in
                        // 关闭 fullScreenCover，动画结束后直接从 window 弹出系统分享面板
                        // 不用 SwiftUI .sheet，避免与 fullScreenCover 的层级冲突
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                            let vc = UIActivityViewController(activityItems: [img], applicationActivities: nil)
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                                var top = root
                                while let presented = top.presentedViewController { top = presented }
                                if let popover = vc.popoverPresentationController {
                                    popover.sourceView = top.view
                                    popover.sourceRect = CGRect(x: top.view.bounds.midX,
                                                                y: top.view.bounds.midY,
                                                                width: 0, height: 0)
                                    popover.permittedArrowDirections = []
                                }
                                top.present(vc, animated: true)
                            }
                        }
                    },
                    onNewPhoto: { photo in
                        // Use Photo 点击后：重新合成，绑定自动刷新预览
                        recompose(with: photo)
                    },
                    onDismiss: {
                        isPresented = false
                    }
                )
                .onAppear {
                    // 首次打开合成初始预览
                    if let photo = preCapturedImage {
                        recompose(with: photo)
                    }
                }
            }

    }
}

// MARK: - View Extension

extension View {
    /// 将完整 share 流程挂载到当前 View
    /// - Parameters:
    ///   - isPresented: 设为 true 即触发流程（拍照 → 合成 → 分享面板）
    ///   - replyText: AI 回复文字，嵌入合成图片
    ///   - preCapturedImage: App 自动抓拍的照片（用于发给 AI 的那张，优先用于分享）
    func shareFlow(isPresented: Binding<Bool>, replyText: String, preCapturedImage: UIImage?) -> some View {
        modifier(ShareFlowModifier(isPresented: isPresented, replyText: replyText, preCapturedImage: preCapturedImage))
    }
}
