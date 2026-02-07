//
//  FaceDetectionProvider.swift
//  Bestie-Check
//
//  人脸检测接口协议定义
//
// 本文件暂时用来测试接口协议的设计，后续会接入实际的人脸检测逻辑（如使用 FaceLandmarkerService 的结果）

import Foundation

// MARK: - 人脸检测接口协议
/// 用于获取人脸检测状态的协议，可以由不同的检测服务实现
protocol FaceDetectionProvider {
    /// 是否检测到人脸
    var faceDetected: Bool { get }
}

// MARK: - 默认实现（暂时返回 false）
/// 默认的人脸检测提供者，目前返回未检测到
/// TODO: 接入实际的人脸检测逻辑
class DefaultFaceDetectionProvider: FaceDetectionProvider {
    var faceDetected: Bool {
        // 默认为 false（未检测到人脸）
        // 待接入实际检测逻辑时，可以基于 FaceLandmarkerService 的结果返回
        return false
    }
}
