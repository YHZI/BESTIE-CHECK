//
//  SharePreviewView.swift
//  Bestie-Check
//
//  按照 Figma 原型实现的分享预览界面
//

import SwiftUI
import Photos

// MARK: - 主要的 Share Preview 界面
struct SharePreviewView: View {
    // 传入参数
    let selfieImage: UIImage?             // 从前面流程中获取的自拍照片
    let aiReplyText: String              // AI 反馈文本
    let onRetake: () -> Void             // 重拍回调
    let onDismiss: () -> Void            // 关闭/返回回调
    
    // 内部状态管理
    @State private var showingSaveSuccess = false
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部区域 - Logo
                topLogoSection
                
                Spacer()
                
                // 中间区域 - 主要内容气泡
                mainContentBubble
                
                Spacer()
                
                // 底部区域 - 操作按钮
                bottomActionSection
            }
            
            // 左上角取消按钮
            topLeftCancelButton
        }
        .alert("保存成功", isPresented: $showingSaveSuccess) {
            Button("确定") { }
        } message: {
            Text("图片已保存到相册")
        }
        .alert("保存失败", isPresented: $showingSaveError) {
            Button("确定") { }
        } message: {
            Text(saveErrorMessage)
        }
    }
    
    // MARK: - 左上角取消按钮
    private var topLeftCancelButton: some View {
        VStack {
            HStack {
                BackButton(
                    diameter: 22,
                    isTextBarExpanded: .constant(nil),
                    onResetDetection: nil,
                    isLongTextMode: .constant(nil),
                    action: {
                        print("🔙 Share Preview - Cancel button tapped")
                        onDismiss()
                    }
                )
                .padding(.leading, 24)
                .padding(.top, 60)
                Spacer()
            }
            Spacer()
        }
    }
    
    // MARK: - 顶部 Logo 区域
    private var topLogoSection: some View {
        HStack(spacing: 8) {
            // 小章鱼 Logo (来自 Assets 中的 LogoIcon)
            Image("LogoIcon")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
            
            // GOSHSHA 文字
            Text("GOSHSHA")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.top, 100)
    }
    
    // MARK: - 中间主要内容气泡
    private var mainContentBubble: some View {
        SharePreviewBubble(
            selfieImage: selfieImage,
            aiReplyText: aiReplyText
        )
        .padding(.horizontal, 24)
    }
    
    // MARK: - 底部操作按钮区域
    private var bottomActionSection: some View {
        ShareActionButtons(
            onSave: {
                print("💾 Save to Photos tapped")
                handleSaveToPhotos()
            },
            onRetake: {
                print("📷 Retake photo tapped")
                onRetake()
            }
        )
        .padding(.bottom, 80)
    }
    
    // MARK: - 保存到相册的处理函数
    private func handleSaveToPhotos() {
        guard let image = selfieImage else {
            saveErrorMessage = "没有可保存的图片"
            showingSaveError = true
            return
        }
        
        // 检查相册访问权限
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.saveImageToPhotos(image)
                case .denied, .restricted:
                    self.saveErrorMessage = "需要相册访问权限，请在设置中允许"
                    self.showingSaveError = true
                case .notDetermined:
                    self.saveErrorMessage = "无法确定相册访问权限"
                    self.showingSaveError = true
                @unknown default:
                    self.saveErrorMessage = "发生未知错误"
                    self.showingSaveError = true
                }
            }
        }
    }
    
    private func saveImageToPhotos(_ image: UIImage) {
        let imageSaver = ImageSaver()
        imageSaver.successHandler = {
            DispatchQueue.main.async {
                self.showingSaveSuccess = true
            }
        }
        imageSaver.errorHandler = { error in
            DispatchQueue.main.async {
                self.saveErrorMessage = "保存失败：\(error.localizedDescription)"
                self.showingSaveError = true
            }
        }
        
        imageSaver.writeToPhotoAlbum(image: image)
    }
    
    // 独立的 ImageSaver 类
    class ImageSaver: NSObject {
        var successHandler: (() -> Void)?
        var errorHandler: ((Error) -> Void)?
        
        func writeToPhotoAlbum(image: UIImage) {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
        }
        
        @objc func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
            if let error = error {
                errorHandler?(error)
            } else {
                successHandler?()
            }
        }
    }
    
    // MARK: - 分享预览气泡组件
    struct SharePreviewBubble: View {
        let selfieImage: UIImage?
        let aiReplyText: String
        
        // 使用与现有 ReactTextBar 相同的颜色
        private let bubbleColor = Color(red: 0xEC/255, green: 0xEF/255, blue: 0xF3/255)
        
        var body: some View {
            VStack(spacing: 20) {
                // 自拍照片（带彩色渐变边框）
                selfieImageSection
                
                // AI 反馈文本
                aiReplyTextSection
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(bubbleColor.opacity(0.85)) // 参考现有的气泡透明度
            )
        }
        
        // MARK: - 自拍照片区域
        private var selfieImageSection: some View {
            Group {
                if let image = selfieImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0x69/255.0, green: 0xAC/255.0, blue: 0x14/255.0),
                                            Color(red: 0x49/255.0, green: 0x3D/255.0, blue: 0x89/255.0),
                                            Color(red: 0xF8/255.0, green: 0x4C/255.0, blue: 0x4C/255.0)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )
                } else {
                    // 占位符
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                }
            }
        }
        
        // MARK: - AI 反馈文本区域
        private var aiReplyTextSection: some View {
            Text(aiReplyText.isEmpty ? "No AI feedback" : aiReplyText)
                .font(.system(size: 14))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .lineLimit(3)  // 限制行数
                .truncationMode(.tail)  // 超出部分显示省略号
        }
    }
    
    // MARK: - 预览
    #Preview {
        struct PreviewWrapper: View {
            @State private var selfieImage = UIImage(systemName: "person.fill")
            
            var body: some View {
                SharePreviewView(
                    selfieImage: selfieImage,
                    aiReplyText: "This is a sample AI feedback text that might be a bit longer to test the truncation.",
                    onRetake: { print("Retake") },
                    onDismiss: { print("Dismiss") }
                )
            }
        }
        
        return PreviewWrapper()
    }
}
