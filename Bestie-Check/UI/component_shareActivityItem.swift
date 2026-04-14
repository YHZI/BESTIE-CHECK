//
//  component_shareActivityItem.swift
//  Bestie-Check
//
//  Share 功能封装：图片合成 + 相机拍照 + 系统分享面板
//

import SwiftUI
import UIKit
import CoreText

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

        // ── 3. 用户照片（aspect-fill，居中裁剪）─────────────────────────
        let imgSize  = photo.size
        let imgScale = max(ptSize.width  / max(imgSize.width,  1),
                           ptSize.height / max(imgSize.height, 1))
        let drawW    = imgSize.width  * imgScale
        let drawH    = imgSize.height * imgScale
        let drawRect = CGRect(
            x: (ptSize.width  - drawW) / 2,
            y: (ptSize.height - drawH) / 2,
            width: drawW, height: drawH
        )
        cgCtx.saveGState()
        cgCtx.clip(to: bounds)
        photo.draw(in: drawRect)
        cgCtx.restoreGState()

        // ── 4. 白色蒙版（80%）────────────────────────────────────────────
        UIColor.white.withAlphaComponent(0.80).setFill()
        ctx.fill(bounds)

        // ── 5. 品牌 header（Logo + "GOSHSHA"，水平居中）──────────────────
        let headerH:  CGFloat = ptSize.height * 0.13
        let logoSize: CGFloat = headerH * 0.70 * 1.10   // 放大 10%
        let brandGap: CGFloat = logoSize * 0.25
        let centerY:  CGFloat = headerH / 2 + headerH * 0.20   // 下移 20%

        let brandFont = playwriteFont(size: ptSize.height * 0.10 * 0.38)  // 字体大小锁定，不随 headerH 变化
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
            logoImage.draw(in: CGRect(
                x: startX,
                y: centerY - logoH / 2,
                width: logoW, height: logoH
            ))
        }
        brandText.draw(
            in: CGRect(
                x: startX + logoSize + brandGap,
                y: centerY - brandTextSize.height / 2,
                width: brandTextSize.width,
                height: brandTextSize.height
            ),
            withAttributes: brandAttrs
        )

        // ── 6. 大圆角照片方框 ─────────────────────────────────────────────
        let boxPadding: CGFloat = ptSize.width  * 0.03    // 左右各 3% 留白
        let boxTop:     CGFloat = headerH + ptSize.height * 0.02
        let boxWidth:   CGFloat = ptSize.width  - boxPadding * 2
        let boxBottom:  CGFloat = ptSize.height - ptSize.height * 0.03  // 底部 3% 留白
        let boxHeight:  CGFloat = boxBottom - boxTop
        let boxCorner:  CGFloat = boxWidth * 0.08
        let strokeW:    CGFloat = 3.0

        let boxRect = CGRect(x: boxPadding, y: boxTop, width: boxWidth, height: boxHeight)

        // 填充：淡灰占位色
        let fillPath = UIBezierPath(roundedRect: boxRect, cornerRadius: boxCorner)
        UIColor.black.withAlphaComponent(0.06).setFill()
        fillPath.fill()

        // 渐变描边：三色循环（69AC14 → 493D89 → F84C4C → 69AC14）
        // 技巧：将描边路径扩展为 clip region，再在上面绘制渐变
        let strokePath = UIBezierPath(roundedRect: boxRect, cornerRadius: boxCorner)
        strokePath.lineWidth = strokeW

        cgCtx.saveGState()

        // 用"描边 clip"：把描边区域设为裁剪区
        // 先 clip 到描边区域（外扩 stroke/2，内缩 stroke/2）
        cgCtx.setLineWidth(strokeW)
        cgCtx.addPath(strokePath.cgPath)
        cgCtx.replacePathWithStrokedPath()   // 将描边路径转换为填充路径
        cgCtx.clip()                          // clip 到描边区域

        // 在 clip 区域内绘制锥形渐变（沿方框一圈循环）
        // 使用线性渐变从左上 → 右下 → 左上 覆盖整个 boxRect，颜色循环
        let c1 = UIColor(red: 0x69/255.0, green: 0xAC/255.0, blue: 0x14/255.0, alpha: 1)
        let c2 = UIColor(red: 0x49/255.0, green: 0x3D/255.0, blue: 0x89/255.0, alpha: 1)
        let c3 = UIColor(red: 0xF8/255.0, green: 0x4C/255.0, blue: 0x4C/255.0, alpha: 1)

        // 渐变色带：c1 → c2 → c3 → c1（循环闭合）
        let gradColors = [c1.cgColor, c2.cgColor, c3.cgColor, c1.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 0.33, 0.66, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace,
                                  colors: gradColors,
                                  locations: locations)!

        // 对角线方向渐变，覆盖整个 boxRect，让颜色环绕方框一圈
        // 两个端点沿方框对角线，保证四条边都能看到颜色变化
        let gradStart = CGPoint(x: boxRect.minX, y: boxRect.minY)
        let gradEnd   = CGPoint(x: boxRect.maxX, y: boxRect.maxY)
        cgCtx.drawLinearGradient(gradient,
                                  start: gradStart,
                                  end: gradEnd,
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
    /// 触发整个 share 流程的开关，由父视图控制
    @Binding var isPresented: Bool
    /// AI 回复文字，用于合成图片
    let replyText: String

    @State private var isShareSheetPresented: Bool = false
    @State private var shareActivityItems: [Any] = []

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                ShareCameraPicker { image in
                    isPresented = false
                    let reply = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let image, !reply.isEmpty else { return }
                    shareActivityItems = [makeShareImage(photo: image, replyText: reply)]
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isShareSheetPresented = true
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isShareSheetPresented, onDismiss: {
                shareActivityItems = []
            }) {
                ShareSheet(activityItems: shareActivityItems)
            }
    }
}

// MARK: - View Extension

extension View {
    /// 将完整 share 流程挂载到当前 View
    /// - Parameters:
    ///   - isPresented: 设为 true 即触发流程（拍照 → 合成 → 分享面板）
    ///   - replyText: AI 回复文字，嵌入合成图片
    func shareFlow(isPresented: Binding<Bool>, replyText: String) -> some View {
        modifier(ShareFlowModifier(isPresented: isPresented, replyText: replyText))
    }
}
