//
//  CountdownManager.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08-16.
//

import Foundation
import AVFoundation
import SwiftUI

protocol CountdownManagerDelegate {
    func countdownManager(_ manager: CountdownManager, didUpdateCount count: Int)
    func countdownManagerDidReachZero(_ manager: CountdownManager)
    func countdownManager(_ manager: CountdownManager, didEncounterError error: Error)
}

class CountdownManager: ObservableObject {
    @Published var currentCount: Int = 3
    @Published var isCountingDown: Bool = false
    @Published var progress: Double = 0.0 // 0.0〜1.0（0秒に向けて進む）
    
    var delegate: CountdownManagerDelegate?
    
    private var countdownTimer: Timer?
    private var progressTimer: Timer?
    private let countdownInterval: TimeInterval = 1.0
    private let progressUpdateInterval: TimeInterval = 0.05 // 20fps
    private var countdownStartTime: Date?
    
    // Audio feedback
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioEnabled: Bool = true
    
    init() {
        setupAudio()
    }
    
    deinit {
        stopCountdown()
        audioEngine?.stop()
    }
    
    private func setupAudio() {
        do {
            audioEngine = AVAudioEngine()
            audioPlayerNode = AVAudioPlayerNode()
            
            guard let engine = audioEngine, let player = audioPlayerNode else { 
                print("CountdownManager: Failed to create audio components")
                audioEnabled = false
                return 
            }
            
            // 1チャンネル、44.1kHzのフォーマットを明示的に指定
            guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
                print("CountdownManager: Failed to create audio format")
                audioEnabled = false
                return
            }
            
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: audioFormat)
            
            try engine.start()
            print("CountdownManager: Audio engine started successfully")
        } catch {
            print("CountdownManager: Failed to setup audio: \(error)")
            audioEnabled = false
            audioEngine = nil
            audioPlayerNode = nil
        }
    }
    
    // MARK: - Public Interface
    
    func startCountdown() {
        print("CountdownManager: Starting countdown")
        stopCountdown() // 既存のカウントダウンをクリーンアップ
        
        currentCount = 3
        progress = 0.0
        isCountingDown = true
        countdownStartTime = Date()
        
        startCountdownTimer()
        startProgressTimer()
        
        // 開始ビープ音
        playBeep(frequency: 800)
        
        delegate?.countdownManager(self, didUpdateCount: currentCount)
    }
    
    func stopCountdown() {
        print("CountdownManager: Stopping countdown")
        countdownTimer?.invalidate()
        countdownTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        isCountingDown = false
        progress = 0.0
    }
    
    func pauseCountdown() {
        countdownTimer?.invalidate()
        progressTimer?.invalidate()
        isCountingDown = false
    }
    
    func resumeCountdown() {
        if currentCount >= 0 {
            startCountdownTimer()
            startProgressTimer()
            isCountingDown = true
        }
    }
    
    // MARK: - Private Implementation
    
    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: countdownInterval, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
    }
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: progressUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func updateCountdown() {
        guard isCountingDown else { return }
        
        currentCount -= 1
        
        if currentCount > 0 {
            // 通常のカウントダウンビープ音
            playBeep(frequency: 1000)
            delegate?.countdownManager(self, didUpdateCount: currentCount)
        } else if currentCount == 0 {
            // 0秒到達 - 特別なシャッター音
            playShutterSound()
            triggerCameraFlash()
            delegate?.countdownManagerDidReachZero(self)
            
            // カウントダウン終了
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.stopCountdown()
            }
        }
    }
    
    private func updateProgress() {
        guard isCountingDown, let startTime = countdownStartTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let totalDuration: TimeInterval = 3.0 // 3秒
        
        progress = min(elapsed / totalDuration, 1.0)
        
        if progress >= 1.0 {
            progress = 1.0
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }
    
    // MARK: - Audio Feedback
    
    private func playBeep(frequency: Float) {
        guard audioEnabled else { return }
        generateTone(frequency: frequency, duration: 0.1)
    }
    
    private func playShutterSound() {
        guard audioEnabled else { return }
        // シャッター風の音（短い高音）
        generateTone(frequency: 1500, duration: 0.05)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.generateTone(frequency: 1200, duration: 0.05)
        }
    }
    
    private func generateTone(frequency: Float, duration: TimeInterval) {
        guard audioEnabled else { return }
        
        guard let engine = audioEngine, let player = audioPlayerNode else { 
            print("CountdownManager: Audio components not available")
            return 
        }
        
        guard engine.isRunning else {
            print("CountdownManager: Audio engine not running")
            return
        }
        
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        
        // 接続時と同じフォーマットを使用
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            print("CountdownManager: Failed to create audio format")
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("CountdownManager: Failed to create audio buffer")
            return
        }
        
        buffer.frameLength = frameCount
        
        guard let samples = buffer.floatChannelData?[0] else {
            print("CountdownManager: Failed to get audio channel data")
            return
        }
        
        // 音声データ生成
        for i in 0..<Int(frameCount) {
            let sample = sin(2.0 * Float.pi * frequency * Float(i) / Float(sampleRate))
            samples[i] = sample * 0.1 // 音量調整
        }
        
        // 安全にバッファをスケジュール
        do {
            player.scheduleBuffer(buffer)
            if !player.isPlaying {
                player.play()
            }
        } catch {
            print("CountdownManager: Failed to schedule audio buffer: \(error)")
        }
    }
    
    // MARK: - Visual Feedback
    
    private func triggerCameraFlash() {
        // フラッシュエフェクトのトリガー（UIで処理）
        NotificationCenter.default.post(name: .cameraFlashTriggered, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cameraFlashTriggered = Notification.Name("cameraFlashTriggered")
}

// MARK: - Countdown State

enum CountdownState {
    case idle
    case counting(Int)
    case zero
    case finished
    
    var displayValue: String {
        switch self {
        case .idle, .finished:
            return ""
        case .counting(let count):
            return "\(count)"
        case .zero:
            return "📸"
        }
    }
}