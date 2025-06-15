//
//  RecognitionCoordinator.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import Combine

enum RecognitionStep {
    case idle
    case recording
    case processing
    case completed
    case error
}

enum RecognitionError: Error, LocalizedError {
    case speechRecognitionFailed
    case aiProcessingFailed
    case networkError
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .speechRecognitionFailed:
            return "语音识别失败，请重试"
        case .aiProcessingFailed:
            return "AI处理失败，请重试"
        case .networkError:
            return "网络连接失败，请检查网络设置"
        case .invalidAPIKey:
            return "API密钥无效，请检查设置"
        }
    }
}

class RecognitionCoordinator: ObservableObject {
    @Published var currentStep: RecognitionStep = .idle
    @Published var recognitionResult: AIResponse?
    @Published var error: RecognitionError?
    @Published var recognizedText: String = ""
    @Published var isLoading: Bool = false
    
    private let speechService = SpeechRecognitionService()
    private let aiService = AIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var isProcessingAI = false // 防止重复调用AI的状态锁
    
    // 公开访问音频级别的计算属性
    var audioLevel: Float {
        return speechService.audioLevel
    }
    
    // 公开的音频引擎预热方法
    func preheatAudioEngineIfNeeded() {
        speechService.preheatAudioEngineIfNeeded()
    }
    
    // 回调闭包
    var onRecordingComplete: ((AIResponse) -> Void)?
    var onCancel: (() -> Void)?
    
    init(onRecordingComplete: ((AIResponse) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self.onRecordingComplete = onRecordingComplete
        self.onCancel = onCancel
        setupBindings()
    }
    
    private func setupBindings() {
        // 监听语音识别结果
        speechService.$recognizedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                self.recognizedText = text
                
                // 移除自动处理逻辑，只更新文本，避免重复调用
                print("DEBUG: Recognized text: \(text)")
            }
            .store(in: &cancellables)
        
        // 监听语音识别错误
        speechService.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    print("DEBUG: RecognitionCoordinator - Speech recognition error: \(error)")
                    // 只有在没有识别到任何文本时才设置为语音识别失败
                    if self.recognizedText.isEmpty {
                        self.error = .speechRecognitionFailed
                        self.currentStep = .error
                        self.isLoading = false
                    } else {
                        print("DEBUG: RecognitionCoordinator - Ignoring speech error as we have recognized text: '\(self.recognizedText)'")
                    }
                }
            }
            .store(in: &cancellables)
        
        // 监听录音状态变化
        speechService.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                if isRecording {
                    self.currentStep = .recording
                    self.error = nil
                }
            }
            .store(in: &cancellables)
    }
    
    func startVoiceRecognition() {
        print("DEBUG: RecognitionCoordinator - startVoiceRecognition() called")
        
        // 检查当前状态，只有在空闲状态才能开始录音
        guard currentStep == .idle else {
            print("DEBUG: RecognitionCoordinator - Cannot start recording, current step: \(currentStep)")
            return
        }
        
        // 重置状态
        recognizedText = ""
        error = nil
        isLoading = false
        isProcessingAI = false
        
        do {
            try speechService.startRecording()
            currentStep = .recording
            print("DEBUG: RecognitionCoordinator - Voice recognition started successfully")
        } catch {
            print("ERROR: RecognitionCoordinator - Failed to start voice recognition: \(error)")
            self.error = .speechRecognitionFailed
            currentStep = .error
        }
    }
    
    func stopVoiceRecognition() {
        print("DEBUG: RecognitionCoordinator - stopVoiceRecognition called")
        
        // 检查当前状态，只有在录音状态才能停止
        guard currentStep == .recording else {
            print("DEBUG: RecognitionCoordinator - Cannot stop recording, current step: \(currentStep)")
            return
        }
        
        speechService.stopRecording()
        
        print("DEBUG: RecognitionCoordinator - Current recognized text: '\(recognizedText)'")
        
        // 立即检查是否有识别文本，如果有则进入处理状态
        if !recognizedText.isEmpty {
            print("DEBUG: RecognitionCoordinator - Processing recognized text immediately")
            currentStep = .processing
            isLoading = true
            processRecognizedText()
        } else {
            print("DEBUG: RecognitionCoordinator - No text recognized yet, waiting for final result...")
            // 设置处理状态，显示"AI处理中"
            currentStep = .processing
            isLoading = true
            
            // 等待语音识别的最终结果
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                print("DEBUG: RecognitionCoordinator - After waiting, recognized text: '\(self.recognizedText)'")
                if !self.recognizedText.isEmpty {
                    print("DEBUG: RecognitionCoordinator - Processing recognized text after waiting")
                    self.processRecognizedText()
                } else {
                    // 如果仍然没有识别到文本，重置到空闲状态
                    print("DEBUG: RecognitionCoordinator - No text recognized after waiting, resetting to idle")
                    if self.currentStep == .processing {
                        self.reset()
                    }
                }
            }
        }
    }
    
    private func processRecognizedText() {
        print("DEBUG: RecognitionCoordinator - processRecognizedText called with text: '\(recognizedText)'")
        
        // 检查是否已经在处理AI请求
        guard !isProcessingAI else {
            print("DEBUG: RecognitionCoordinator - AI processing already in progress, ignoring duplicate call")
            return
        }
        
        guard !recognizedText.isEmpty else { 
            print("ERROR: RecognitionCoordinator - Empty recognized text")
            DispatchQueue.main.async {
                self.error = .speechRecognitionFailed
                self.currentStep = .error
                self.isLoading = false
            }
            return 
        }
        
        // 设置处理状态锁
        isProcessingAI = true
        currentStep = .processing
        isLoading = true
        error = nil
        
        print("DEBUG: RecognitionCoordinator - Starting AI processing...")
        
        // 保存当前识别的文本，避免在异步处理过程中被清空
        let textToProcess = recognizedText
        
        // 添加网络权限预检查和延迟处理
        Task {
            // 首先进行网络权限预检查
            await performNetworkPermissionPrecheck()
            
            // 添加短暂延迟，确保权限提醒完成后再调用AI
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒延迟
            
            do {
                let result = try await aiService.processText(textToProcess)
                print("DEBUG: RecognitionCoordinator - AI processing completed successfully")
                await MainActor.run {
                    self.isProcessingAI = false // 释放状态锁
                    self.recognitionResult = result
                    self.currentStep = .completed
                    self.isLoading = false
                    
                    print("DEBUG: RecognitionCoordinator - Recognition completed, calling callback")
                    // 调用完成回调
                    if let onRecordingComplete = self.onRecordingComplete {
                        onRecordingComplete(result)
                    }
                }
            } catch {
                print("ERROR: RecognitionCoordinator - AI processing failed: \(error)")
                await MainActor.run {
                    self.isProcessingAI = false // 释放状态锁
                    if let aiError = error as? AIServiceError {
                        switch aiError {
                        case .invalidAPIKey:
                            self.error = .invalidAPIKey
                        case .networkError:
                            self.error = .networkError
                        default:
                            self.error = .aiProcessingFailed
                        }
                    } else {
                        self.error = .aiProcessingFailed
                    }
                    self.currentStep = .error
                    self.isLoading = false
                }
            }
        }
    }
    
    func processText(_ text: String) {
        recognizedText = text
        processRecognizedText()
    }
    
    private var isResetting = false
    
    func reset() {
        print("[RecognitionCoordinator] reset() called")
        
        // 防止重复调用
        guard !isResetting else {
            print("[RecognitionCoordinator] Reset already in progress, skipping")
            return
        }
        
        isResetting = true
        
        // 先停止语音识别服务
        speechService.stopRecording()
        
        // 立即重置UI状态
        DispatchQueue.main.async {
            self.currentStep = .idle
            self.recognitionResult = nil
            self.error = nil
            self.recognizedText = ""
            self.isLoading = false
            self.isProcessingAI = false
        }
        
        // 异步执行强制重置音频会话
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.speechService.forceResetAudioSession()
            
            // 重置完成后解除锁定
            DispatchQueue.main.async {
                self.isResetting = false
                print("[RecognitionCoordinator] reset() completed")
            }
        }
    }
    
    func retry() {
        reset()
        startVoiceRecognition()
    }
    
    // 网络权限预检查
    private func performNetworkPermissionPrecheck() async {
        print("DEBUG: RecognitionCoordinator - Performing network permission precheck")
        
        // 创建一个简单的网络请求来触发权限提醒
        guard let url = URL(string: "https://httpbin.org/get") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0
            request.httpMethod = "HEAD" // 使用HEAD请求减少数据传输
            
            let _ = try await URLSession.shared.data(for: request)
            print("DEBUG: RecognitionCoordinator - Network permission precheck completed successfully")
        } catch {
            print("DEBUG: RecognitionCoordinator - Network permission precheck failed (expected for first time): \(error)")
            // 首次网络请求失败是正常的，因为会触发权限提醒
            // 这里不需要处理错误，只是为了触发权限提醒
        }
    }
}