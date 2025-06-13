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
    
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var error: String?
    
    init() {
        requestAuthorization()
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
        do {
        print("DEBUG: SpeechRecognitionService - Attempting to start recording...")
        startRecordingTime = Date() // 设置录音开始时间

        // Aggressively clean up any existing task and request BEFORE calling stopRecordingInternal
        if let task = recognitionTask, task.state == .running || task.state == .starting {
            print("DEBUG: SpeechRecognitionService - startRecording: Cancelling existing recognitionTask.")
            task.cancel()
        }
        recognitionTask = nil
        recognitionRequest = nil
        // audioEngine.inputNode.removeTap(onBus: 0) // This might be needed if tap persists across stop/start
        // audioEngine.stop() // Ensure engine is stopped before re-preparing

        stopRecordingInternal(caller: "startRecording_initial_cleanup") // Clean up any existing session before starting a new one

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            print("ERROR: SpeechRecognitionService - Speech recognition not authorized.")
            throw SpeechRecognitionError.notAuthorized
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("ERROR: SpeechRecognitionService - Speech recognizer is not available.")
            throw SpeechRecognitionError.recognizerNotAvailable
        }

        // Configure audio session
        print("DEBUG: SpeechRecognitionService - Configuring audio session...")
        let audioSession = AVAudioSession.sharedInstance() // Define audioSession
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

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
            
            // Use the input node's output format for the tap, but ensure it's valid.
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                self.error = "无效的录音格式 (采样率或声道数为0)。请检查麦克风权限或模拟器设置。"
                print("ERROR: Invalid recording format from inputNode. SampleRate: \(recordingFormat.sampleRate), Channels: \(recordingFormat.channelCount)")
                self.stopRecording()
                return
            }
            print("DEBUG: SpeechRecognitionService - Recording format: \(recordingFormat)")

            // Install a tap on the input node to receive audio buffers.
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
                self.recognitionRequest?.append(buffer)
            }
            print("DEBUG: SpeechRecognitionService - Tap installed.")

            // Start recognition task.
            guard let recognizer = speechRecognizer else { // Safely unwrap speechRecognizer
                self.error = "Speech recognizer not initialized."
                print("ERROR: Speech recognizer is nil before starting task.")
                self.stopRecordingInternal(caller: "recognitionTask_recognizer_nil")
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
                                print("DEBUG: No speech detected (Error 1101). Silently ignoring to prevent infinite loop.")
                                // 不设置error，避免触发无限循环
                                // 静默处理1101错误，让任务自然结束
                                currentError = nil // 静默处理此错误
                            } else if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                                self.error = "未检测到语音 (1110)。请重试。"
                                print("DEBUG: No speech detected (Error 1110) - (isRecording was likely true or different error). Calling stopRecordingInternal if recording.")
                                if self.isRecording { // Only stop if still actively recording
                                   self.stopRecordingInternal(caller: "recognitionTask_error_1110_active")
                                }
                            } else if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1107 {
                                 self.error = "语音识别超时。请重试。"
                                 print("DEBUG: Speech recognition timed out (Error 1107).")
                                 // Consider stopping if it's a timeout and still recording
                                 if self.isRecording {
                                     self.stopRecordingInternal(caller: "recognitionTask_error_1107_timeout")
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
                                    self.stopRecordingInternal(caller: "recognitionTask_other_error")
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
                                        self.stopRecordingInternal(caller: "recognitionTask_final_empty_result_still_recording")
                                    }
                                } else {
                                    // Final, no active error, and text is present - success!
                                    print("DEBUG: Final recognition result received with text: \(self.recognizedText)")
                                    // Ensure recording stops if it hasn't already been stopped by user action
                                    if self.isRecording {
                                        self.stopRecordingInternal(caller: "recognitionTask_final_cleanup_still_recording")
                                    }
                                }
                            } else {
                                // isFinal is true, but there's an active (non-silenced) error
                                print("DEBUG: SpeechRecognitionService - recognitionTask completion: isFinal true, but an error occurred. Calling stop for error cleanup if recording.")
                                if self.isRecording {
                                    self.stopRecordingInternal(caller: "recognitionTask_error_with_final_still_recording")
                                }
                            }
                        } else if currentError != nil {
                            // Not final, but an active error occurred (e.g., a non-1110 error, or 1110 when isRecording was true)
                            print("DEBUG: SpeechRecognitionService - recognitionTask completion: Not isFinal, but an error occurred. Calling stop for error cleanup if recording.")
                            if self.isRecording {
                                self.stopRecordingInternal(caller: "recognitionTask_error_not_final_still_recording")
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
            try audioEngine.start() // This line was problematic, it should be a call followed by a block if it's async with completion, or just the call.
                                  // Assuming it's a synchronous call or its completion is handled elsewhere/implicitly based on typical AVAudioEngine usage.
                                  // If it were meant to have a completion handler like `try audioEngine.start { ... }`, that block was missing.
                                  // For now, treating it as a direct call.
            
            print("DEBUG: SpeechRecognitionService - Audio engine started.")

            DispatchQueue.main.async {
                self.isRecording = true
            }
            print("DEBUG: SpeechRecognitionService started recording successfully.")
        } catch {
            DispatchQueue.main.async {
                print("DEBUG: SpeechRecognitionService - Audio session/engine setup FAILED: \(error.localizedDescription)")
                self.error = error.localizedDescription
                // Attempt to stop everything cleanly if setup fails
                self.stopRecordingInternal(caller: "startRecordingCatch_error_handling")
            }
        } // This closes the do-catch block for startRecording
   }

    func stopRecording() {
        // 添加一个小延迟，确保录音至少持续一段时间
        // 这样可以避免因为用户快速点击导致的录音时间太短而无法识别
        let minimumRecordingDuration: TimeInterval = 0.5
        let recordingDuration = Date().timeIntervalSince(startRecordingTime ?? Date().addingTimeInterval(-minimumRecordingDuration))
        
        if recordingDuration < minimumRecordingDuration {
            // 如果录音时间太短，延迟停止录音
            DispatchQueue.main.asyncAfter(deadline: .now() + (minimumRecordingDuration - recordingDuration)) { [weak self] in
                self?.stopRecordingInternal(caller: "external_public_api_delayed")
            }
        } else {
            stopRecordingInternal(caller: "external_public_api")
        }
    }

    private func stopRecordingInternal(caller: String) {
        print("DEBUG: SpeechRecognitionService - stopRecordingInternal() called by \(caller). audioEngine.isRunning: \(audioEngine.isRunning), recognitionTask state: \(recognitionTask?.state.rawValue ?? -1), recognitionRequest isNil: \(recognitionRequest == nil)")
        
        // 重置录音开始时间
        startRecordingTime = nil
        
        // Check if already stopped or in the process of stopping to avoid redundant calls or race conditions
        // Allow proceeding if called from error handling in startRecording or recognitionTask, as resources might be partially initialized/active.
        if !audioEngine.isRunning && recognitionTask == nil && recognitionRequest == nil && caller != "startRecordingCatch_error_handling" && caller != "recognitionTask_error" {
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() called by \(caller), but already seems stopped. No action taken.")
            return
        }

        if audioEngine.isRunning {
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): Stopping audioEngine.")
            audioEngine.stop()
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): Removing tap on inputNode.")
            audioEngine.inputNode.removeTap(onBus: 0)
        } else {
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): audioEngine was not running. Attempting to remove tap if inputNode is available.")
            if audioEngine.inputNode.outputFormat(forBus: 0).channelCount > 0 { 
                 audioEngine.inputNode.removeTap(onBus: 0)
                 print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): Tap removed (engine was not running).")
            } else {
                print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): Tap not removed as inputNode seems unconfigured (engine was not running).")
            }
        }

        // We will now always attempt to call endAudio() to allow any buffered audio to be processed,
        // even if the task was .starting and stopped externally.
        // The error handling in the recognitionTask callback will be adjusted to ignore
        // a potential 1110 error if the task was already nilled by an external stop.
        if recognitionRequest != nil {
                print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): Ending audio on recognitionRequest.")
                recognitionRequest?.endAudio()

        } else {
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): recognitionRequest was already nil, cannot end audio.")
        }

        if caller == "external_public_api" || caller == "external_public_api_delayed" {
            // 对于外部调用，我们需要取消任务以避免潜在的回调问题
            if let task = recognitionTask {
                print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): Cancelling recognitionTask to prevent callback issues. Current state: \(task.state.rawValue)")
                task.cancel()
                recognitionTask = nil
            } else {
                print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): recognitionTask was already nil.")
            }
        } else if recognitionTask != nil {
            // For internal calls (errors, final cleanup from task itself, or startup issues)
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): Cancelling recognitionTask. Current state: \(recognitionTask?.state.rawValue ?? -1)")
            recognitionTask?.cancel()
            recognitionTask = nil
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): recognitionTask cancelled and set to nil.")
        } else { 
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): recognitionTask was already nil.")
        }
        
        // 统一清理recognitionRequest，避免资源泄漏
        if recognitionRequest != nil {
            recognitionRequest = nil
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): recognitionRequest set to nil.")
        } else {
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): recognitionRequest was already nil.")
        }

        do {
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): Attempting to deactivate audio session.")
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): Audio session deactivated.")
        } catch {
            print("ERROR: SpeechRecognitionService - stopRecordingInternal() by \(caller): Failed to deactivate audio session: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
            if self.isRecording { 
                self.isRecording = false
                print("DEBUG: SpeechRecognitionService - stopRecordingInternal() by \(caller): isRecording set to false on main thread.")
            }
        }
        print("DEBUG: SpeechRecognitionService - Finished stopRecordingInternal() called by \(caller).")
    }
    
}
