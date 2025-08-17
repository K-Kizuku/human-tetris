//
//  GameResultView.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI
import SwiftData
import AVFoundation

struct GameResultView: View {
    let finalScore: Int
    let linesCleared: Int
    let playTime: TimeInterval
    let onReplay: () -> Void
    let onExit: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingShareSheet = false
    @State private var newRecord = false
    
    // 音声管理
    private func playMenuBGM() {
        AudioManager.shared.playMenuBGM()
    }
    
    private func playButtonSound() {
        AudioManager.shared.playButtonSound()
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text("ゲーム終了")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if newRecord {
                        Text("🎉 新記録！")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                            .scaleEffect(1.2)
                            .animation(.bouncy, value: newRecord)
                    }
                }
                
                VStack(spacing: 20) {
                    ResultCard(
                        title: "最終スコア",
                        value: "\(finalScore)",
                        icon: "star.fill",
                        color: .yellow
                    )
                    
                    HStack(spacing: 15) {
                        ResultCard(
                            title: "ライン消去",
                            value: "\(linesCleared)",
                            icon: "equal.square.fill",
                            color: .green,
                            compact: true
                        )
                        
                        ResultCard(
                            title: "プレイ時間",
                            value: formatTime(playTime),
                            icon: "clock.fill",
                            color: .blue,
                            compact: true
                        )
                    }
                }
                
                VStack(spacing: 15) {
                    HStack(spacing: 15) {
                        Button("もう一度") {
                            playButtonSound()
                            onReplay()
                        }
                        .buttonStyle(PrimaryGameButtonStyle())
                        
                        Button("スクリーンショット") {
                            playButtonSound()
                            shareScreenshot()
                        }
                        .buttonStyle(SecondaryGameButtonStyle())
                    }
                    
                    Button("ホームに戻る") {
                        playButtonSound()
                        onExit()
                    }
                    .buttonStyle(TertiaryGameButtonStyle())
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            playMenuBGM()
            saveGameResult()
            checkForNewRecord()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func saveGameResult() {
        let gameScore = GameScore(
            finalScore: finalScore,
            linesCleared: linesCleared,
            maxIoU: 0.0, // TODO: 実際のIoU値を記録
            averageIoU: 0.0, // TODO: 実際のIoU値を記録
            playTimeSeconds: Int(playTime),
            diversityIndex: 0.0, // TODO: 実際の多様性指数を記録
            difficulty: "normal" // TODO: 実際の難易度を記録
        )
        
        modelContext.insert(gameScore)
        try? modelContext.save()
    }
    
    private func checkForNewRecord() {
        // TODO: 過去のスコアと比較して新記録判定
        if finalScore > 1000 { // 仮の条件
            newRecord = true
        }
    }
    
    private func shareScreenshot() {
        // TODO: スクリーンショット機能の実装
        showingShareSheet = true
    }
}

struct ResultCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let compact: Bool
    
    init(title: String, value: String, icon: String, color: Color, compact: Bool = false) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.compact = compact
    }
    
    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            Image(systemName: icon)
                .font(compact ? .title2 : .largeTitle)
                .foregroundColor(color)
            
            Text(title)
                .font(compact ? .caption : .headline)
                .foregroundColor(.white.opacity(0.8))
            
            Text(value)
                .font(compact ? .title3 : .title)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? 16 : 24)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PrimaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                configuration.isPressed ? 
                Color.green.opacity(0.8) : 
                Color.green
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                configuration.isPressed ? 
                Color.blue.opacity(0.8) : 
                Color.blue.opacity(0.7)
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TertiaryGameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                configuration.isPressed ? 
                Color.gray.opacity(0.6) : 
                Color.gray.opacity(0.4)
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    GameResultView(
        finalScore: 12500,
        linesCleared: 25,
        playTime: 300,
        onReplay: {},
        onExit: {}
    )
    .modelContainer(for: [GameScore.self], inMemory: true)
}