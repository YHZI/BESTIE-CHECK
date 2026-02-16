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
        
        static let `default` = Config(
            endpoint: "https://api.example.com/v1/chat/completions",  // TODO: 替换为你的真实 endpoint
            apiKey: "YOUR_API_KEY_HERE",  // ⚠️ 不安全：仅用于 Demo，请使用后端代理模式
            headers: [
                "Content-Type": "application/json"
            ],
            timeout: 10.0,
            maxRetries: 2
        )
        
        // 推荐：后端代理模式配置
        static let backendProxy = Config(
            endpoint: "https://your-backend.com/api/face-analysis",  // TODO: 实现后端代理
            apiKey: nil,  // 后端处理认证
            headers: [
                "Content-Type": "application/json"
            ],
            timeout: 10.0,
            maxRetries: 2
        )
    }
    
    private let config: Config
    private let session: URLSession
    
    // MARK: - Initialization
    init(config: Config = .default) {
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
