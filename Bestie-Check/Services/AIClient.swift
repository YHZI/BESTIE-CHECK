//
//  AIClient.swift
//  Bestie-Check
//
//  AI API 封装层：将人脸分析结果发送到 AI API，获取回复
//

import Foundation
import CoreVideo
import UIKit

/// AIClient: 封装 AI API 调用
class AIClient {
    // MARK: - Configuration
    struct Config {
        var endpoint: String
        var apiKey: String?
        var headers: [String: String]
        var timeout: TimeInterval
        var maxRetries: Int
        
        // 直连 OpenAI API 配置（仅用于 Demo，不推荐用于生产）
        static let direct = Config(
            endpoint: "https://api.openai.com/v1/chat/completions",
            apiKey: "YOUR_API_KEY_HERE",  // ⚠️ 不安全：仅用于 Demo，请使用后端代理模式
            headers: [
                "Content-Type": "application/json"
            ],
            timeout: 10.0,
            maxRetries: 2
        )
        
        // 后端代理模式配置（推荐，默认使用）
        static var backendProxy: Config {
            Config(
                endpoint: AIClient.backendProxyBaseURL + "/api/face-analysis",
                apiKey: nil,  // 后端处理认证，不传 API Key
                headers: [
                    "Content-Type": "application/json"
                ],
                timeout: 10.0,
                maxRetries: 2
            )
        }
    }
    
    // MARK: - Backend Proxy Base URL Configuration
    /// 后端代理服务的 base URL
    /// - Debug 模式：模拟器使用 localhost，真机使用电脑 IP（需手动修改）
    /// - Release 模式：使用生产环境的 HTTPS 地址
    static var backendProxyBaseURL: String {
        #if DEBUG
        #if targetEnvironment(simulator)
        // 模拟器可以直接使用 localhost
        return "http://localhost:8080"
        #else
        // 真机调试时，需要改为你电脑的 IP 地址
        // 例如：return "http://192.168.1.100:8080"
        // 查看电脑 IP：macOS 终端运行 `ipconfig getifaddr en0` 或系统设置 → 网络 → Wi-Fi 详情
        //return "http://localhost:8080"  // ⚠️ 真机调试时请改为 http://<你电脑IP>:8080
        return "http://192.168.0.12:8080"
        #endif
        #else
        // Release 模式：使用生产环境的 HTTPS 地址
        // 正式发布时，请将下面的地址改为你部署的后端服务的公网地址
        // 例如：return "https://bestie-check-backend.railway.app"
        return "https://your-backend.example.com"  // ⚠️ 正式发布前请改为实际的后端地址
        #endif
    }
    
    private let config: Config
    private let session: URLSession
    
    // MARK: - Initialization
    /// 初始化 AIClient
    /// - Parameter config: 配置，默认为 backendProxy（后端代理模式）
    init(config: Config = .backendProxy) {
        self.config = config
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.timeoutIntervalForResource = config.timeout * 2
        self.session = URLSession(configuration: sessionConfig)
    }
    
    // MARK: - API Call
    /// 发送人脸分析摘要到 AI API，获取文本回复
    func getAIReply(
        summary: FaceAnalysisSummary,
        includeImage: Bool = false,
        imageBase64: String? = nil
    ) async throws -> String {
        let requestBody = AIRequest(
            faceAnalysis: summary,
            imageBase64: includeImage ? imageBase64 : nil
        )
        
        var retries = 0
        var lastError: Error?
        
        while retries <= config.maxRetries {
            do {
                return try await performRequest(requestBody: requestBody)
            } catch {
                lastError = error
                retries += 1
                if retries <= config.maxRetries {
                    // 指数退避
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retries - 1)) * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NSError(domain: "AIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request failed after retries"])
    }
    
    private func performRequest(requestBody: AIRequest) async throws -> String {
        guard let url = URL(string: config.endpoint) else {
            throw NSError(domain: "AIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid endpoint URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 设置 headers
        for (key, value) in config.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 添加 API Key（如果使用直接调用模式）
        if let apiKey = config.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // 编码请求体
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)
        
        // 发送请求
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "AIClient",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode): \(errorMessage)"]
            )
        }
        
        // 解析响应
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let aiResponse = try decoder.decode(AIResponse.self, from: data)
        
        if let error = aiResponse.error {
            throw NSError(domain: "AIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        
        return aiResponse.message
    }
    
    // MARK: - Stream Support (Optional)
    /// 流式 SSE 请求（可选实现）
    func getAIReplyStream(
        summary: FaceAnalysisSummary,
        includeImage: Bool = false,
        imageBase64: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // TODO: 实现 SSE 流式解析
                    // 这里先返回非流式结果
                    let reply = try await getAIReply(summary: summary, includeImage: includeImage, imageBase64: imageBase64)
                    continuation.yield(reply)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Helper: CVPixelBuffer to Base64
extension AIClient {
    static func pixelBufferToBase64(_ pixelBuffer: CVPixelBuffer) -> String? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let imageData = uiImage.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        
        return imageData.base64EncodedString()
    }
}
