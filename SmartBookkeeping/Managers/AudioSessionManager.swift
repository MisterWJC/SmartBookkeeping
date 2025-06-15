//
//  AudioSessionManager.swift
//  SmartBookkeeping
//
//  Created by Assistant on 2025/1/27.
//

import Foundation
import AVFoundation

class AudioSessionManager {
    static let shared = AudioSessionManager()
    private var isConfigured = false
    
    private init() {}
    
    func preconfigureAudioSession() {
        guard !isConfigured else { 
            print("DEBUG: AudioSessionManager - Audio session already configured, skipping")
            return 
        }
        
        print("DEBUG: AudioSessionManager - Preconfiguring audio session")
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            isConfigured = true
            print("DEBUG: AudioSessionManager - Audio session preconfigured successfully")
        } catch {
            print("DEBUG: AudioSessionManager - Audio session preconfiguration failed: \(error)")
        }
    }
    
    func resetConfiguration() {
        isConfigured = false
        print("DEBUG: AudioSessionManager - Configuration reset")
    }
    
    var isAudioSessionConfigured: Bool {
        return isConfigured
    }
}