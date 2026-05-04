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

/// 全局共享的 AVCaptureSession，在 App 启动时即开始预热，
/// 避免每次打开 Share 界面都冷启动摄像头。
@MainActor
final class SharedCameraSession: ObservableObject {
    static let shared = SharedCameraSession()

    let session = AVCaptureSession()
    @Published private(set) var isPrepared = false
    @Published private(set) var isReady = false

    private init() {
        // 完全异步化：在后台线程预热，不阻塞主线程
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.prepare()
        }
    }

    private func prepare() async {
        guard !isPrepared else { return }
        
        // 在后台线程执行所有 AVCaptureSession 配置
        await Task.detached(priority: .userInitiated) {
            let session = self.session
            session.sessionPreset = .high

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                           ?? AVCaptureDevice.default(for: .video),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                print("❌ Failed to prepare SharedCameraSession")
                return
            }

            session.addInput(input)
            
            // 立即开始跑，等 UI 挂上 previewLayer 后画面就能即时显示
            session.startRunning()
            
            await MainActor.run {
                self.isPrepared = true
                self.isReady = true
                print("✅ SharedCameraSession prepared and running")
            }
        }.value
    }

    /// 暂停（释放摄像头给相机拍照 picker）
    func pause() {
        guard session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.stopRunning()
        }
    }

    /// 恢复（相机拍照 picker 关闭后）
    func resume() {
        guard !session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.session.startRunning()
        }
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
            SharedCameraSession.shared.resume()
        } else {
            SharedCameraSession.shared.pause()
        }
    }

    static func dismantleUIView(_ uiView: CameraPreviewUIView, coordinator: ()) {
        uiView.stop()
    }
}
