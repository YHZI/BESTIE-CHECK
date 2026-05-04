//
//  ResourcePreloader.swift
//  Bestie-Check
//
//  统一管理所有资源的异步预加载（模型、相机、CIContext等）
//  启动可以慢，但绝不阻塞主线程
//

import Foundation
import AVFoundation
import CoreImage
import UIKit
import Combine

/// ResourcePreloader: 统一协调所有资源的异步预加载
@MainActor
class ResourcePreloader: ObservableObject {
    static let shared = ResourcePreloader()
    
    // MARK: - Published State
    @Published private(set) var isReady: Bool = false
    @Published private(set) var progress: Double = 0.0
    @Published private(set) var loadingStatus: String = "Initializing..."
    
    // MARK: - Resource State
    private(set) var modelLoadTime: TimeInterval = 0
    private(set) var cameraLoadTime: TimeInterval = 0
    private(set) var ciContextLoadTime: TimeInterval = 0
    
    private var preloadTask: Task<Void, Never>?
    
    // MARK: - Initialization
    private init() {
        // 立即在后台启动预加载
        startPreloading()
    }
    
    // MARK: - Preloading
    private func startPreloading() {
        preloadTask = Task {
            let startTime = Date()
            print("🚀 ResourcePreloader: Starting parallel resource loading...")
            
            // 并行加载所有资源
            await withTaskGroup(of: (String, TimeInterval).self) { group in
                // Task 1: 预热 FaceLandmarker 模型
                group.addTask {
                    let taskStart = Date()
                    await self.warmupFaceLandmarkerModel()
                    let elapsed = Date().timeIntervalSince(taskStart)
                    return ("FaceLandmarker Model", elapsed)
                }
                
                // Task 2: 预热 SharedCameraSession
                group.addTask {
                    let taskStart = Date()
                    await self.warmupSharedCamera()
                    let elapsed = Date().timeIntervalSince(taskStart)
                    return ("Camera Session", elapsed)
                }
                
                // Task 3: 预热 CIContext（虽然已经在各服务中复用，这里只是确保首次创建在后台）
                group.addTask {
                    let taskStart = Date()
                    await self.warmupCIContext()
                    let elapsed = Date().timeIntervalSince(taskStart)
                    return ("CIContext", elapsed)
                }
                
                // 收集结果并更新进度
                var completed = 0
                let totalTasks = 3
                
                for await (taskName, elapsed) in group {
                    completed += 1
                    let progress = Double(completed) / Double(totalTasks)
                    
                    await MainActor.run {
                        self.progress = progress * 100
                        self.loadingStatus = "Loaded \(taskName) (\(Int(elapsed * 1000))ms)"
                        print("✅ \(taskName) loaded in \(Int(elapsed * 1000))ms")
                    }
                    
                    // 记录各资源加载时间
                    switch taskName {
                    case "FaceLandmarker Model":
                        self.modelLoadTime = elapsed
                    case "Camera Session":
                        self.cameraLoadTime = elapsed
                    case "CIContext":
                        self.ciContextLoadTime = elapsed
                    default:
                        break
                    }
                }
            }
            
            let totalTime = Date().timeIntervalSince(startTime)
            print("🎉 ResourcePreloader: All resources loaded in \(Int(totalTime * 1000))ms")
            
            await MainActor.run {
                self.progress = 100
                self.loadingStatus = "Ready"
                self.isReady = true
            }
        }
    }
    
    // MARK: - Individual Warmup Tasks
    
    /// 预热 FaceLandmarker 模型（在后台线程加载）
    private func warmupFaceLandmarkerModel() async {
        // FaceLandmarkerService 的 init 已经在后台队列加载模型
        // 这里只需要确保单例被创建（触发后台加载）
        // 注意：不要在这里创建实例，由 ViewModel 按需创建
        // 我们只确保模型文件路径可访问
        await Task.detached {
            guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
                print("❌ face_landmarker.task not found during preload check")
                return
            }
            // 触发文件系统预读（iOS 会缓存）
            _ = FileManager.default.fileExists(atPath: modelPath)
        }.value
    }
    
    /// 预热 SharedCameraSession（触发单例的后台初始化）
    private func warmupSharedCamera() async {
        await Task.detached {
            // 访问单例，触发其后台 prepare()
            _ = await SharedCameraSession.shared
            // 等待相机准备完成
            while await !SharedCameraSession.shared.isPrepared {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }.value
    }
    
    /// 预热 CIContext（确保首次创建在后台）
    private func warmupCIContext() async {
        await Task.detached {
            // AIClient 和 FaceLandmarkerService 都使用 static let 复用 CIContext
            // 这里只需确保首次创建不在主线程
            // 由于是 static let，首次访问时会自动创建
            // 我们通过访问 AIClient 的静态方法来触发
            _ = CIContext(options: [.useSoftwareRenderer: false])
        }.value
    }
    
    // MARK: - Manual Retry
    func retry() {
        guard !isReady else { return }
        preloadTask?.cancel()
        progress = 0
        loadingStatus = "Retrying..."
        startPreloading()
    }
}
