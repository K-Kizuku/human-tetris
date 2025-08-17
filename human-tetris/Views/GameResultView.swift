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
        AudioManager.shared.playMenuBGM()  // 実際にはSFX（ループなし）
    }
    
    private func playButtonSound() {
        AudioManager.shared.playButtonSound()
    }
    
    var body: some View {
        ZStack {
            // ネオン宇宙背景
            NeonColors.mainBackgroundGradient
                .ignoresSafeArea()
            
            // パーティクル効果背景
            NeonParticleBackground()
            
            ScrollView {
                VStack(spacing: 40) {
                    Spacer(minLength: 40)
                    
                    // ネオンヘッダー
                    VStack(spacing: 20) {
                        Text("ゲーム終了")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .neonGlow(color: NeonColors.neonPink, radius: 15, intensity: 1.2)
                        
                        if newRecord {
                            VStack(spacing: 8) {
                                Text("🎉 新記録！ 🎉")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(NeonColors.neonYellow)
                                    .scaleEffect(1.2)
                                    .pulsingNeon(color: NeonColors.neonYellow)
                                
                                Text("素晴らしいスコアです！")
                                    .font(.headline)
                                    .foregroundColor(NeonColors.neonCyan)
                                    .neonGlow(color: NeonColors.neonCyan, radius: 8)
                            }
                            .animation(.bouncy, value: newRecord)
                        }
                    }
                    
                    // ネオンスコアカード
                    VStack(spacing: 20) {
                        NeonResultCard(
                            title: "最終スコア",
                            value: "\(finalScore)",
                            icon: "star.fill",
                            color: NeonColors.neonYellow,
                            glowColor: NeonColors.neonYellow
                        )
                        
                        HStack(spacing: 15) {
                            NeonResultCard(
                                title: "ライン消去",
                                value: "\(linesCleared)",
                                icon: "equal.square.fill",
                                color: NeonColors.neonGreen,
                                glowColor: NeonColors.neonGreen,
                                compact: true
                            )
                            
                            NeonResultCard(
                                title: "プレイ時間",
                                value: formatTime(playTime),
                                icon: "clock.fill",
                                color: NeonColors.neonCyan,
                                glowColor: NeonColors.neonCyan,
                                compact: true
                            )
                        }
                    }
                    
                    // ネオンボタン
                    VStack(spacing: 20) {
                        HStack(spacing: 15) {
                            Button("もう一度") {
                                playButtonSound()
                                onReplay()
                            }
                            .buttonStyle(NeonPrimaryButtonStyle())
                            
                            Button("スクリーンショット") {
                                playButtonSound()
                                shareScreenshot()
                            }
                            .buttonStyle(NeonSecondaryButtonStyle())
                        }
                        
                        Button("ホームに戻る") {
                            playButtonSound()
                            onExit()
                        }
                        .buttonStyle(NeonTertiaryButtonStyle())
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
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

/// ネオンリザルトカード
struct NeonResultCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let glowColor: Color
    let compact: Bool
    
    init(title: String, value: String, icon: String, color: Color, glowColor: Color, compact: Bool = false) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.glowColor = glowColor
        self.compact = compact
    }
    
    var body: some View {
        VStack(spacing: compact ? 8 : 16) {
            Image(systemName: icon)
                .font(compact ? .title2 : .system(size: 40))
                .foregroundColor(color)
                .neonGlow(color: glowColor, radius: compact ? 6 : 10, intensity: 1.0)
            
            Text(title)
                .font(compact ? .caption : .headline)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))
            
            Text(value)
                .font(compact ? .title3 : .system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .neonGlow(color: glowColor, radius: compact ? 4 : 8, intensity: 0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? 16 : 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(NeonColors.spaceBlack.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(glowColor, lineWidth: 1.5)
                )
        )
        .neonGlow(color: glowColor, radius: compact ? 8 : 12, intensity: 0.6)
    }
}

/// ネオンプライマリボタンスタイル
struct NeonPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(NeonColors.buttonGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(NeonColors.neonPink, lineWidth: 1)
                    )
            )
            .neonGlow(
                color: NeonColors.neonPink, 
                radius: configuration.isPressed ? 6 : 12, 
                intensity: configuration.isPressed ? 0.8 : 1.0
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// ネオンセカンダリボタンスタイル
struct NeonSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(NeonColors.secondaryButtonGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(NeonColors.neonCyan, lineWidth: 1)
                    )
            )
            .neonGlow(
                color: NeonColors.neonCyan, 
                radius: configuration.isPressed ? 6 : 10, 
                intensity: configuration.isPressed ? 0.7 : 0.9
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// ネオンターシャリボタンスタイル
struct NeonTertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [NeonColors.neonPurple.opacity(0.6), NeonColors.deepPurple.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(NeonColors.neonPurple.opacity(0.7), lineWidth: 1)
                    )
            )
            .neonGlow(
                color: NeonColors.neonPurple, 
                radius: configuration.isPressed ? 4 : 8, 
                intensity: configuration.isPressed ? 0.5 : 0.7
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0.0)
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