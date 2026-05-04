//
//  CameraPreviewLayer.swift
//  Bestie-Check
//
//  轻量级实时相机预览，仅用于背景，不携带任何 UI
//

import SwiftUI
import AVFoundation
import UIKit
import Combine

// MARK: - Shared Session Singleton

/// 全局共享的 AVCaptureSession，按需启动（只在打开 Share 界面时）
/// ⚠️ 注意：不能在 App 启动时自动运行，会与 ARSession 冲突导致 "AR session interrupted"
@MainActor
final class SharedCameraSession: ObservableObject {
    static let shared = SharedCameraSession()

    let session = AVCaptureSession()
    @Published private(set) var isPrepared = false
    @Published private(set) var isReady = false
    
    // 使用 nonisolated(unsafe) 因为这个标志只在后台配置线程中访问
    // AVCaptureSession 的线程安全性保证了这个访问是安全的
    nonisolated(unsafe) private var isConfigured = false

    private init() {
        // 不再自动启动，改为延迟配置
        print("📷 SharedCameraSession initialized (will start on demand)")
    }

    /// 按需准备并启动 session（从 CameraPreview.updateUIView 调用）
    func prepareIfNeeded() async {
        // 在主 actor 上检查
        guard !isPrepared else { return }
        
        // 在后台线程执行所有 AVCaptureSession 配置
        await Task.detached(priority: .userInitiated) { [session] in
            // 配置 session（只做一次）
            if !self.isConfigured {
                session.sessionPreset = .high

                guard
                    let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                               ?? AVCaptureDevice.default(for: .video),
                    let input = try? AVCaptureDeviceInput(device: device),
                    session.canAddInput(input)
                else {
                    print("❌ Failed to configure SharedCameraSession")
                    return
                }

                session.addInput(input)
                self.isConfigured = true
                print("✅ SharedCameraSession configured")
            }
            
            // 启动 session
            if !session.isRunning {
                session.startRunning()
                print("▶️ SharedCameraSession started")
            }
            
            await MainActor.run {
                self.isPrepared = true
                self.isReady = true
            }
        }.value
    }

    /// 暂停（释放摄像头给 ARSession 或相机拍照 picker）
    func pause() {
        guard session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
            print("⏸️ SharedCameraSession paused")
            await MainActor.run {
                self.isPrepared = false
                self.isReady = false
            }
        }
    }

    /// 恢复（从分享界面返回时调用）
    func resume() async {
        // 在主 actor 上检查 isConfigured（通过 isPrepared 间接判断）
        // 如果从未配置过，isPrepared 会是 false，调用 prepareIfNeeded
        if !isConfigured {
            await prepareIfNeeded()
            return
        }
        
        guard !session.isRunning else { return }
        
        await Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
            print("▶️ SharedCameraSession resumed")
            await MainActor.run {
                self.isPrepared = true
                self.isReady = true
            }
        }.value
    }
}

// MARK: - UIKit Layer

final class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // 复用全局共享 session —— 已预热则立即出画面，否则等 prepare() 完成
        let layer = AVCaptureVideoPreviewLayer(session: SharedCameraSession.shared.session)
        layer.videoGravity = .resizeAspectFill
        self.layer.insertSublayer(layer, at: 0)
        self.previewLayer = layer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    /// 仅在整个 Share 界面关闭时调用（dismantleUIView）
    func stop() {
        SharedCameraSession.shared.pause()
    }
}

// MARK: - SwiftUI Wrapper

struct CameraPreview: UIViewRepresentable {
    /// true = 正常预览；false = 暂停 session（让位给相机 picker）
    var isActive: Bool = true

    func makeUIView(context: Context) -> CameraPreviewUIView {
        CameraPreviewUIView()
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if isActive {
            // 异步启动相机（不阻塞）
            Task {
                await SharedCameraSession.shared.resume()
            }
        } else {
            SharedCameraSession.shared.pause()
        }
    }

    static func dismantleUIView(_ uiView: CameraPreviewUIView, coordinator: ()) {
        uiView.stop()
    }
}
