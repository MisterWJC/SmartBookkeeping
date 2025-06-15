//
//  VoiceRecordingGuideView.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import SwiftUI
import AVFoundation

struct VoiceRecordingGuideView: View {
    let onRecordingComplete: (AIResponse) -> Void
    let onCancel: () -> Void
    
    @StateObject private var coordinator: RecognitionCoordinator
    @State private var recordingStartTime: Date?
    @State private var recordingTimer: Timer?
    @State private var silenceTimer: Timer?
    @State private var lastAudioLevel: Float = 0.0
    @State private var silenceStartTime: Date?
    @State private var audioLevelTimer: Timer?
    
    // 网络权限预检查状态标记
    @State private static var hasPerformedNetworkCheck = false
    
    private let minimumRecordingDuration: TimeInterval = 0.5
    private let maximumRecordingDuration: TimeInterval = 15.0
    private let silenceDuration: TimeInterval = 2.5 // 静音持续时间阈值
    
    init(onRecordingComplete: @escaping (AIResponse) -> Void, onCancel: @escaping () -> Void) {
        self.onRecordingComplete = onRecordingComplete
        self.onCancel = onCancel
        self._coordinator = StateObject(wrappedValue: RecognitionCoordinator(
            onRecordingComplete: onRecordingComplete,
            onCancel: onCancel
        ))
        
        // 预配置音频会话以提升性能
        AudioSessionManager.shared.preconfigureAudioSession()
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 1. 顶部标题区域
                VStack(spacing: 12) {
                    Text("语音记账")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(coordinator.currentStep == .idle ? "点击说话，快速记录" : "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
                
                // 2. 第一个Spacer - 将主要交互元素推向中心
                Spacer()
                
                // 3. 中心交互区域 - 录音按钮和声波动画
                ZStack {
                    // 声波动画 - 多层圆圈
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                coordinator.currentStep == .recording ? 
                                Color.red.opacity(0.3 - Double(index) * 0.1) : 
                                Color.green.opacity(0.3 - Double(index) * 0.1), 
                                lineWidth: 2
                            )
                            .frame(
                                width: min(geometry.size.width, geometry.size.height) * (0.5 + Double(index) * 0.15),
                                height: min(geometry.size.width, geometry.size.height) * (0.5 + Double(index) * 0.15)
                            )
                            .scaleEffect(coordinator.currentStep == .recording ? 1.0 + Double(index) * 0.2 : 1.0)
                            .opacity(coordinator.currentStep == .recording ? 0.8 - Double(index) * 0.2 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.0 + Double(index) * 0.3)
                                .repeatForever(autoreverses: true), 
                                value: coordinator.currentStep == .recording
                            )
                    }
                    
                    // 录音按钮
                    Button(action: {
                        handleButtonTap()
                    }) {
                        ZStack {
                            Circle()
                                .fill(coordinator.currentStep == .recording ? Color.red : Color.green)
                                .frame(width: 120, height: 120)
                                .shadow(
                                    color: coordinator.currentStep == .recording ? .red.opacity(0.3) : .green.opacity(0.3), 
                                    radius: 10, x: 0, y: 5
                                )
                            
                            if coordinator.currentStep == .processing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            } else {
                                Image(systemName: coordinator.currentStep == .recording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .scaleEffect(coordinator.currentStep == .recording ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: coordinator.currentStep == .recording)
                    .disabled(coordinator.currentStep == .processing)
                }
                .padding(.vertical, 20)
                
                // 4. 动态内容区域 - 实时识别文本显示
                VStack(spacing: 20) {
                    if coordinator.currentStep == .error {
                        // 错误状态
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("出现错误")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            if let error = coordinator.error {
                                Text(error.errorDescription ?? "未知错误")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Text("点击话筒重新录音")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if !coordinator.recognizedText.isEmpty {
                        // 实时识别文本显示 - 大字体醒目显示
                        VStack(spacing: 12) {
                            Text("识别内容")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(coordinator.recognizedText)
                                .font(.title)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )
                        }
                    } else {
                        // 状态提示文字
                        Text(statusText)
                            .font(.title2)
                            .foregroundColor(statusColor)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.3), value: coordinator.currentStep)
                    }
                }
                .frame(minHeight: 150)
                .padding(.horizontal, 24)
                .animation(.easeInOut, value: coordinator.currentStep)
                
                // 5. Spacer - 将取消按钮推向底部
                Spacer()
                
                // 6. 底部取消按钮
                Button("取消") {
                    stopAllTimers()
                    coordinator.reset()
                    onCancel()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .cornerRadius(20)
                .padding(.bottom)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
    private var statusText: String {
        switch coordinator.currentStep {
        case .idle:
            return "点击说话，快速记录"
        case .recording:
            return "正在录音..."
        case .processing:
            return "AI处理中..."
        case .completed:
            return "处理完成"
        case .error:
            return "处理失败"
        }
    }
    
    private var statusColor: Color {
        switch coordinator.currentStep {
        case .idle:
            return .secondary
        case .recording:
            return .red
        case .processing:
            return .blue
        case .completed:
            return .green
        case .error:
            return .orange
        }
    }
    
    // MARK: - 按钮点击处理方法
    private func handleButtonTap() {
        if coordinator.currentStep == .recording {
            // 当前正在录音，点击停止录音
            stopRecording()
        } else if coordinator.currentStep == .idle {
            // 当前空闲，点击开始录音
            startRecording()
        } else if coordinator.currentStep == .error {
            // 当前错误状态，重置后开始录音
            coordinator.reset()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.startRecording()
            }
        }
    }
    
    private func startRecording() {
        guard coordinator.currentStep == .idle else {
            print("DEBUG: Cannot start recording, current step: \(coordinator.currentStep)")
            return
        }
        
        // 异步执行网络权限预检查（如果需要），但不阻塞录音启动
        Task {
            await performNetworkPermissionPrecheckIfNeeded()
        }
        
        // 预热音频引擎（如果尚未预热）
        coordinator.preheatAudioEngineIfNeeded()
        
        // 直接开始录音，不等待网络权限检查
        print("DEBUG: Starting voice recognition immediately")
        coordinator.startVoiceRecognition()
        
        // 设置录音开始时间
        recordingStartTime = Date()
        
        // 启动15秒计时器
        recordingTimer = Timer.scheduledTimer(withTimeInterval: maximumRecordingDuration, repeats: false) { _ in
            self.handleMaxTimeReached()
        }
        
        // 启动音频级别监测定时器
        startAudioLevelMonitoring()
    }
    
    private func stopRecording() {
        guard coordinator.currentStep == .recording else {
            print("DEBUG: Not in recording state, current step: \(coordinator.currentStep)")
            return
        }
        
        stopAllTimers()
        
        let recordingDuration = recordingStartTime?.timeIntervalSinceNow.magnitude ?? 0
        print("DEBUG: Recording duration: \(recordingDuration)s")
        
        if recordingDuration < minimumRecordingDuration {
            // 录音时间过短，显示提示并重置到初始状态
            print("DEBUG: Recording too short (\(recordingDuration)s), resetting to idle")
            coordinator.reset()
        } else {
            // 录音时间足够，正常处理
            print("DEBUG: Recording duration sufficient, stopping voice recognition")
            
            // 停止录音 - stopVoiceRecognition内部已经会处理识别的文本
            coordinator.stopVoiceRecognition()
        }
        
        recordingStartTime = nil
    }
    
    private func handleMaxTimeReached() {
        print("DEBUG: Maximum recording time reached (\(maximumRecordingDuration)s), stopping recording")
        
        // 停止录音 - stopVoiceRecognition内部已经会处理识别的文本
        coordinator.stopVoiceRecognition()
        recordingStartTime = nil
        stopAllTimers()
    }
    
    // MARK: - 静音检测相关方法
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.checkAudioLevel()
        }
    }
    
    private func checkAudioLevel() {
        // 获取当前音频级别（从RecognitionCoordinator获取实际值）
        let currentLevel = coordinator.audioLevel
        
        // 静音阈值设为 -50dB，低于此值认为是静音
        if currentLevel < -50.0 {
            if silenceStartTime == nil {
                silenceStartTime = Date()
                print("DEBUG: 开始检测静音，音频级别: \(currentLevel)dB")
            } else if let startTime = silenceStartTime,
                      Date().timeIntervalSince(startTime) >= silenceDuration {
                // 检测到持续静音，自动停止录音
                print("DEBUG: 检测到\(silenceDuration)秒静音，自动停止录音")
                stopRecording()
            }
        } else {
            // 有声音，重置静音计时
            if silenceStartTime != nil {
                print("DEBUG: 检测到声音，重置静音计时，音频级别: \(currentLevel)dB")
            }
            silenceStartTime = nil
        }
        
        lastAudioLevel = currentLevel
    }
    
    private func stopAllTimers() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        silenceStartTime = nil
    }
    
    // 网络权限预检查 - 只在首次使用时执行
    private func performNetworkPermissionPrecheckIfNeeded() async {
        guard !Self.hasPerformedNetworkCheck else {
            print("DEBUG: VoiceRecordingGuideView - Network permission precheck already performed, skipping")
            return
        }
        
        print("DEBUG: VoiceRecordingGuideView - Performing network permission precheck (first time)")
        
        // 创建一个简单的网络请求来触发权限提醒
        guard let url = URL(string: "https://httpbin.org/get") else { return }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3.0
            request.httpMethod = "HEAD" // 使用HEAD请求减少数据传输
            
            let _ = try await URLSession.shared.data(for: request)
            print("DEBUG: VoiceRecordingGuideView - Network permission precheck completed successfully")
        } catch {
            print("DEBUG: VoiceRecordingGuideView - Network permission precheck failed (expected for first time): \(error)")
            // 首次网络请求失败是正常的，因为会触发权限提醒
            // 这里不需要处理错误，只是为了触发权限提醒
        }
        
        // 标记已完成网络权限检查
        Self.hasPerformedNetworkCheck = true
    }
}

#Preview {
    VoiceRecordingGuideView(
        onRecordingComplete: { result in
            print("录音完成：\(result)")
        },
        onCancel: {
            print("取消录音")
        }
    )
}