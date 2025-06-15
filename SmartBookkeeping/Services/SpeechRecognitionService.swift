import Foundation
import Speech
import AVFoundation

enum SpeechRecognitionError: Error {
    case notAuthorized
    case recognizerNotAvailable
    case audioEngineError
    case recognitionRequestError
    case recognitionTaskError
    case invalidRecordingFormat
    // Add other specific error cases as needed
}

class SpeechRecognitionService: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var startRecordingTime: Date?
    private var hasTapInstalled = false // 跟踪tap是否已安装
    private var isStoppingRecording = false // 防止重复停止操作
    private var audioSessionActive = false // 跟踪音频会话状态
    private let audioSessionQueue = DispatchQueue(label: "audioSession", qos: .userInitiated) // 专用音频会话队列
    private var isAudioEnginePreheated = false // 跟踪音频引擎是否已预热
    
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var error: String?
    @Published var audioLevel: Float = 0.0 // 音频级别，范围 -160.0 到 0.0 (dB)
    
    init() {
        requestAuthorization()
        // 预配置音频会话
        AudioSessionManager.shared.preconfigureAudioSession()
        // 注意：音频引擎预热需要在用户交互后进行，不能在初始化时调用
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self?.error = nil
                case .denied:
                    self?.error = "语音识别权限被拒绝"
                case .restricted:
                    self?.error = "语音识别在此设备上受限"
                case .notDetermined:
                    self?.error = "语音识别权限未确定"
                @unknown default:
                    self?.error = "未知错误"
                }
            }
        }
    }
    
    func startRecording() throws {
        print("DEBUG: SpeechRecognitionService - Attempting to start recording...")
        
        // 防止重复启动
        guard !isRecording && !isStoppingRecording else {
            print("DEBUG: SpeechRecognitionService - Already recording or stopping, ignoring start request")
            return
        }
        
        startRecordingTime = Date()
        
        // 彻底清理之前的状态
        cleanupAudioResources()
        
        do {

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("ERROR: SpeechRecognitionService - Speech recognition not authorized.")
            throw SpeechRecognitionError.notAuthorized
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("ERROR: SpeechRecognitionService - Speech recognizer is not available.")
            throw SpeechRecognitionError.recognizerNotAvailable
        }

        // Configure audio session (use preconfig if available)
        print("DEBUG: SpeechRecognitionService - Configuring audio session...")
        let audioSession = AVAudioSession.sharedInstance()
        
        if !AudioSessionManager.shared.isAudioSessionConfigured {
            print("DEBUG: SpeechRecognitionService - Audio session not preconfigured, configuring now")
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        } else {
            print("DEBUG: SpeechRecognitionService - Using preconfigured audio session")
        }
        
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        audioSessionActive = true // 标记音频会话为活跃状态

            // Create recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                self.error = "无法创建识别请求"
                print("ERROR: Could not create recognition request.")
                self.stopRecording() // Ensure cleanup if request creation fails
                return
            }
            recognitionRequest.shouldReportPartialResults = true
            // Keep the task alive until the user stops recording or an error occurs.
            recognitionRequest.taskHint = .dictation // Enable task hint for potentially better recognition

            // IMPORTANT: Access inputNode AFTER audio session is configured and active.
            let inputNode = audioEngine.inputNode
            
            // 确保没有已安装的tap
            if hasTapInstalled {
                inputNode.removeTap(onBus: 0)
                hasTapInstalled = false
                print("DEBUG: SpeechRecognitionService - Removed existing tap")
            }
            
            // Use the input node's output format for the tap, but ensure it's valid.
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                self.error = "无效的录音格式 (采样率或声道数为0)。请检查麦克风权限或模拟器设置。"
                print("ERROR: Invalid recording format from inputNode. SampleRate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)")
                self.cleanupAudioResources()
                return
            }
            print("DEBUG: SpeechRecognitionService - Recording format: \(recordingFormat)")

            // Install a tap on the input node to receive audio buffers.
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                self.recognitionRequest?.append(buffer)
                
                // 计算音频级别
                self.calculateAudioLevel(from: buffer)
            }
            hasTapInstalled = true
            print("DEBUG: SpeechRecognitionService - Tap installed.")

            // Start recognition task.
            guard let recognizer = speechRecognizer else { // Safely unwrap speechRecognizer
                self.error = "Speech recognizer not initialized."
                print("ERROR: Speech recognizer is nil before starting task.")
                self.stopRecordingInternal(isExternal: false)
                return
            }
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                var isFinal = false

                if let result = result {
                    DispatchQueue.main.async {
                        self.recognizedText = result.bestTranscription.formattedString
                        print("DEBUG: Recognized text: \(self.recognizedText)")
                        isFinal = result.isFinal
                    }
                }

                var currentError = error // Make a mutable copy to potentially nil it out for silent handling

                if currentError != nil || isFinal {
                    DispatchQueue.main.async {
                        if let unwrappedError = currentError {
                            let nsError = unwrappedError as NSError
                            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 && !self.isRecording {
                                print("DEBUG: SpeechRecognitionService - recognitionTask completion: Error 1110 (No Speech Detected) occurred, but isRecording is false. Silently ignoring as likely due to quick stop. Will still check for final result.")
                                currentError = nil // Effectively silence this error for subsequent checks
                            } else if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
                                print("DEBUG: Speech service access error (1101). This usually indicates audio session conflicts.")
                                // 1101错误通常表示音频会话冲突，需要重置音频会话
                                currentError = nil // 静默处理此错误
                                // 异步重置音频会话以避免冲突
                                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1) {
                                    self.forceResetAudioSession()
                                }
                            } else if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                                // 如果不在录音状态或者已经有识别文本，静默处理这个错误
                                if !self.isRecording || !self.recognizedText.isEmpty {
                                    currentError = nil
                                } else {
                                    self.error = "未检测到语音 (1110)。请重试。"
                                    print("DEBUG: No speech detected (Error 1110) - (isRecording was likely true or different error). Calling stopRecordingInternal if recording.")
                                    if self.isRecording { // Only stop if still actively recording
                                       self.stopRecordingInternal(isExternal: false)
                                    }
                                }
                            } else if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1107 {
                                // 超时错误，如果有部分识别文本则不报错
                                if !self.isRecording || !self.recognizedText.isEmpty {
                                    currentError = nil
                                } else {
                                    self.error = "语音识别超时。请重试。"
                                    print("DEBUG: Speech recognition timed out (Error 1107).")
                                    // Consider stopping if it's a timeout and still recording
                                    if self.isRecording {
                                        self.stopRecordingInternal(isExternal: false)
                                    }
                                }
                            } else if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 && !self.isRecording {
                                // "Recognition request was canceled" error when not recording - ignore it
                                print("DEBUG: SpeechRecognitionService - recognitionTask completion: Error 301 (Recognition request was canceled) occurred, but isRecording is false. Silently ignoring as likely due to normal stop.")
                                currentError = nil // Silence this error
                            } else {
                                self.error = unwrappedError.localizedDescription
                                print("DEBUG: Speech recognition error object: \(unwrappedError)")
                                print("DEBUG: Speech recognition error localizedDescription: \(unwrappedError.localizedDescription)")
                                // For other errors, stop if still recording
                                if self.isRecording {
                                    self.stopRecordingInternal(isExternal: false)
                                }
                            }
                        }
                        // After potentially silencing the 1110 error, now check isFinal and recognizedText
                        if isFinal {
                            if currentError == nil { // No 'active' error (1110 might have been nilled)
                                if self.recognizedText.isEmpty {
                                    // If it's final, no active error, but text is empty, it's a 'no speech' scenario
                                    // Do not set self.error here. Let TransactionFormView handle empty quickInputText.
                                    print("DEBUG: Final recognition, but no text was recognized (after potential 1110 silent ignore). recognizedText is empty.")
                                    // self.error = "未检测到语音。" // Removed this line
                                    // Ensure recording stops if it hasn't already been stopped by user action
                                    if self.isRecording {
                                        self.stopRecordingInternal(isExternal: false)
                                    }
                                } else {
                                    // Final, no active error, and text is present - success!
                                    print("DEBUG: Final recognition result received with text: \(self.recognizedText)")
                                    // Ensure recording stops if it hasn't already been stopped by user action
                                    if self.isRecording {
                                        self.stopRecordingInternal(isExternal: false)
                                    }
                                }
                            } else {
                                // isFinal is true, but there's an active (non-silenced) error
                                print("DEBUG: SpeechRecognitionService - recognitionTask completion: isFinal true, but an error occurred. Calling stop for error cleanup if recording.")
                                if self.isRecording {
                                    self.stopRecordingInternal(isExternal: false)
                                }
                            }
                        } else if currentError != nil {
                            // Not final, but an active error occurred (e.g., a non-1110 error, or 1110 when isRecording was true)
                            print("DEBUG: SpeechRecognitionService - recognitionTask completion: Not isFinal, but an error occurred. Calling stop for error cleanup if recording.")
                            if self.isRecording {
                                self.stopRecordingInternal(isExternal: false)
                            }
                        }
                        // If not isFinal and currentError is nil, it's a partial result, do nothing here regarding stopping.
                    }
                }
            }
            print("DEBUG: SpeechRecognitionService - Recognition task started.")

            // Prepare the audio engine.
            audioEngine.prepare()
            print("DEBUG: SpeechRecognitionService - Audio engine prepared.")
            
            // Start the audio engine.
            try audioEngine.start()
            print("DEBUG: SpeechRecognitionService - Audio engine started.")

            DispatchQueue.main.async {
                self.isRecording = true
            }
            print("DEBUG: SpeechRecognitionService started recording successfully.")
            
        } catch {
            print("DEBUG: SpeechRecognitionService - Audio session/engine setup FAILED: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.error = error.localizedDescription
            }
            // 清理资源
            cleanupAudioResources()
            throw error
        }
    }

    func stopRecording() {
        // 添加一个小延迟，确保录音至少持续一段时间
        // 这样可以避免因为用户快速点击导致的录音时间太短而无法识别
        let minimumRecordingDuration: TimeInterval = 0.5
        let recordingDuration = Date().timeIntervalSince(startRecordingTime ?? Date().addingTimeInterval(-minimumRecordingDuration))
        
        if recordingDuration < minimumRecordingDuration {
            // 如果录音时间太短，延迟停止录音
            DispatchQueue.main.asyncAfter(deadline: .now() + (minimumRecordingDuration - recordingDuration)) { [weak self] in
                self?.stopRecordingInternal(isExternal: true)
            }
        } else {
            stopRecordingInternal(isExternal: true)
        }
    }

    // MARK: - Private Methods
    
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let channelDataValue = channelData
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataValueArray.count))
        let avgPower = 20 * log10(rms)
        let normalizedPower = max(-160.0, avgPower) // 限制最小值为 -160dB
        
        DispatchQueue.main.async {
            self.audioLevel = normalizedPower
        }
    }
    
    private func stopRecordingInternal(isExternal: Bool = false) {
        print("[SpeechRecognitionService] stopRecordingInternal called, isExternal: \(isExternal)")
        
        // 防止重复停止操作
        guard !isStoppingRecording else {
            print("[SpeechRecognitionService] Already stopping, skipping")
            return
        }
        
        // 添加状态检查，避免重复操作
        guard isRecording else {
            print("[SpeechRecognitionService] Already stopped, skipping")
            return
        }
        
        isStoppingRecording = true
        
        // 立即更新状态，防止重复调用
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // 在后台队列执行音频操作
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 停止音频引擎和移除tap
            if self.audioEngine.isRunning {
                self.audioEngine.stop()
                print("[SpeechRecognitionService] Audio engine stopped")
            }
            
            if self.hasTapInstalled {
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.hasTapInstalled = false
                print("[SpeechRecognitionService] Audio tap removed")
            }
            
            // 结束识别请求
            self.recognitionRequest?.endAudio()
            
            // 如果是外部调用（用户主动停止），立即取消任务
            if isExternal {
                self.recognitionTask?.cancel()
                self.recognitionTask = nil
                self.recognitionRequest = nil
                print("[SpeechRecognitionService] External call - task cancelled immediately")
            }
            
            // 安全地停用音频会话
            self.deactivateAudioSessionSafely()
            
            // 重置停止标志
            DispatchQueue.main.async {
                self.isStoppingRecording = false
            }
        }
        
        print("[SpeechRecognitionService] stopRecordingInternal completed")
    }
    
    func forceResetAudioSession() {
        print("[SpeechRecognitionService] Force resetting audio session...")
        
        // 在专用音频会话队列执行重置
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.cleanupAudioResources()
            
            // 重置音频会话
            let audioSession = AVAudioSession.sharedInstance()
            do {
                // 如果会话当前是活跃的，先停用
                if self.audioSessionActive {
                    try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                    self.audioSessionActive = false
                    print("[SpeechRecognitionService] Audio session deactivated during force reset")
                }
                
                // 等待更长时间确保系统完全清理
                usleep(200000) // 200ms
                
                // 重新配置音频会话
                try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
                
                DispatchQueue.main.async {
                    print("[SpeechRecognitionService] Audio session force reset completed")
                }
            } catch {
                DispatchQueue.main.async {
                    print("[SpeechRecognitionService] Error during force reset: \(error)")
                }
            }
        }
    }
    
    // 新增：统一的资源清理方法
    private func cleanupAudioResources() {
        // 停止音频引擎
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // 移除tap
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }
        
        // 取消识别任务
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // 清理识别请求
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // 重置状态
        isStoppingRecording = false
        
        print("[SpeechRecognitionService] Audio resources cleaned up")
    }
    
    // 新增：安全的音频会话停用方法
    private func deactivateAudioSessionSafely() {
        audioSessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 只有在会话活跃时才尝试停用
            guard self.audioSessionActive else {
                print("[SpeechRecognitionService] Audio session already inactive, skipping deactivation")
                return
            }
            
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                self.audioSessionActive = false
                print("[SpeechRecognitionService] Audio session deactivated safely")
            } catch let error as NSError {
                // 特殊处理560030580错误（会话停用失败）
                if error.code == 560030580 {
                    print("[SpeechRecognitionService] Audio session deactivation failed (560030580), but continuing...")
                    self.audioSessionActive = false // 强制重置状态
                } else {
                    print("[SpeechRecognitionService] Failed to deactivate audio session: \(error)")
                }
            }
        }
    }
    
    // MARK: - 音频引擎预热
    private func preheatAudioEngine() {
        guard !isAudioEnginePreheated else {
            print("DEBUG: SpeechRecognitionService - Audio engine already preheated, skipping")
            return
        }
        
        print("DEBUG: SpeechRecognitionService - Preheating audio engine")
        
        do {
            // 确保音频会话已配置
            let audioSession = AVAudioSession.sharedInstance()
            
            // 如果音频会话未配置，先配置
            if !AudioSessionManager.shared.isAudioSessionConfigured {
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            }
            
            // 激活音频会话
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true)
            }
            
            // 确保输入节点存在并有效
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // 验证录音格式是否有效
            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                print("DEBUG: SpeechRecognitionService - Invalid recording format during preheat, skipping")
                return
            }
            
            // 预热音频引擎但不启动
            audioEngine.prepare()
            isAudioEnginePreheated = true
            print("DEBUG: SpeechRecognitionService - Audio engine preheated successfully")
        } catch {
            print("DEBUG: SpeechRecognitionService - Audio engine preheat failed: \(error)")
            // 预热失败时重置状态
            isAudioEnginePreheated = false
        }
    }
    
    func resetPreheat() {
        isAudioEnginePreheated = false
        print("DEBUG: SpeechRecognitionService - Preheat status reset")
    }
    
    // MARK: - 公开的预热方法
    public func preheatAudioEngineIfNeeded() {
        preheatAudioEngine()
    }
}
