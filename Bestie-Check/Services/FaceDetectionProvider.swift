//
//  FaceDetectionProvider.swift
//  Bestie-Check
//
//  人脸检测接口协议定义
//

import Foundation
import Combine

// MARK: - 人脸检测提供者（可观察）
/// 实时人脸检测状态提供者，与 ViewModel 集成
@MainActor
class FaceDetectionProvider: ObservableObject {
    /// 是否检测到人脸
    @Published var faceDetected: Bool = false
    
    /// 单例实例
    static let shared = FaceDetectionProvider()
    
    private init() {}
    
    /// 更新人脸检测状态
    func updateFaceDetection(detected: Bool) {
        faceDetected = detected
    }
}
