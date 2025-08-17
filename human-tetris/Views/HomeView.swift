//
//  HomeView.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI
import AVFoundation

struct HomeView: View {
    @State private var showingGame = false
    @State private var showingSettings = false
    @State private var showingHowTo = false
    @State private var logoAnimation = false
    @State private var particleAnimation = false
    
    // 音声管理
    private func playMenuBGM() {
        AudioManager.shared.playMenuBGM()  // 実際にはSFX（ループなし）
    }
    
    private func playButtonSound() {
        AudioManager.shared.playButtonSound()
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // ネオン宇宙背景
                    NeonColors.mainBackgroundGradient
                        .ignoresSafeArea()
                    
                    // パーティクル効果背景
                    NeonParticleBackground()
                    
                    // メインコンテンツ
                    VStack(spacing: 0) {
                        Spacer(minLength: geometry.size.height * 0.15)
                        
                        // ネオンロゴセクション
                        VStack(spacing: 20) {
                            // メインタイトル
                            Text("ギラリス")
                                .font(.system(size: min(geometry.size.width * 0.12, 48), weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .neonGlow(color: NeonColors.neonPink, radius: 15, intensity: 1.2)
                                .scaleEffect(logoAnimation ? 1.05 : 1.0)
                                // .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: logoAnimation)
                            
                            // サブタイトル
                            VStack(spacing: 8) {
                                Text("ギラギラした人生を")
                                    .font(.system(size: min(geometry.size.width * 0.045, 18), weight: .semibold))
                                    .foregroundColor(NeonColors.neonCyan)
                                
                                Text("送りましょう")
                                    .font(.system(size: min(geometry.size.width * 0.045, 18), weight: .semibold))
                                    .foregroundColor(NeonColors.neonYellow)
                            }
                            .neonGlow(color: NeonColors.neonCyan, radius: 8, intensity: 0.8)
                        }
                        .padding(.bottom, 40)
                        
                        // ネオンメニューボタン
                        VStack(spacing: 24) {
                            NavigationLink(destination: UnifiedGameView()) {
                                NeonMenuButton(
                                    title: "ゲームスタート", 
                                    icon: "play.fill", 
                                    gradient: NeonColors.buttonGradient,
                                    glowColor: NeonColors.neonPink,
                                    size: geometry.size
                                )
                            }
                            
                            Button(action: { 
                                playButtonSound()
                                showingHowTo = true 
                            }) {
                                NeonMenuButton(
                                    title: "遊び方", 
                                    icon: "questionmark.circle.fill", 
                                    gradient: NeonColors.secondaryButtonGradient,
                                    glowColor: NeonColors.neonCyan,
                                    size: geometry.size
                                )
                            }
                            
                            Button(action: { 
                                playButtonSound()
                                showingSettings = true 
                            }) {
                                NeonMenuButton(
                                    title: "設定", 
                                    icon: "gearshape.fill", 
                                    gradient: LinearGradient(
                                        colors: [NeonColors.neonPurple, NeonColors.deepPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    glowColor: NeonColors.neonPurple,
                                    size: geometry.size
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                        
                        // フッター
                        VStack(spacing: 8) {
                            Text("iOS 18.0+ 対応")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(NeonColors.secondaryText)
                            
                            Text("★ ネオンテトリス体験 ★")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(NeonColors.neonYellow)
                                .pulsingNeon(color: NeonColors.neonYellow)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // アニメーション開始
            logoAnimation = true
            particleAnimation = true
            
            // デバッグ用：音声ファイルの存在確認
            AudioManager.shared.testAudioFiles()
            playMenuBGM()
        }
        .sheet(isPresented: $showingHowTo) {
            HowToPlayView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

/// ネオンメニューボタン
struct NeonMenuButton: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let glowColor: Color
    let size: CGSize
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: min(size.width * 0.05, 20), weight: .semibold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: min(size.width * 0.045, 18), weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: min(size.width * 0.04, 16), weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: min(size.width * 0.8, 320))
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(glowColor, lineWidth: 1.5)
                )
        )
        .neonGlow(color: glowColor, radius: 12, intensity: 1.0)
    }
}

/// ネオンパーティクル背景
struct NeonParticleBackground: View {
    @State private var particles: [NeonParticle] = []
    @State private var animationTimer: Timer?
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .blur(radius: particle.blur)
                    .neonGlow(color: particle.color, radius: particle.size * 0.5, intensity: 0.6)
            }
        }
        .onAppear {
            generateParticles()
            startAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
    }
    
    private func generateParticles() {
        particles = (0..<15).map { _ in
            NeonParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                color: [NeonColors.neonPink, NeonColors.neonCyan, NeonColors.neonPurple, NeonColors.neonGreen].randomElement()!,
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.3...0.8),
                blur: CGFloat.random(in: 1...3)
            )
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                for i in particles.indices {
                    particles[i].position.x += CGFloat.random(in: -1...1)
                    particles[i].position.y += CGFloat.random(in: -1...1)
                    particles[i].opacity = Double.random(in: 0.2...0.9)
                    
                    // 画面外に出たら反対側から再登場
                    if particles[i].position.x < 0 {
                        particles[i].position.x = UIScreen.main.bounds.width
                    } else if particles[i].position.x > UIScreen.main.bounds.width {
                        particles[i].position.x = 0
                    }
                    
                    if particles[i].position.y < 0 {
                        particles[i].position.y = UIScreen.main.bounds.height
                    } else if particles[i].position.y > UIScreen.main.bounds.height {
                        particles[i].position.y = 0
                    }
                }
            }
        }
    }
}

/// パーティクル構造体
struct NeonParticle {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
    let blur: CGFloat
}

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // ネオン背景
                NeonColors.mainBackgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // ヘッダー
                        VStack(spacing: 16) {
                            Text("ギラリス遊び方")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .neonGlow(color: NeonColors.neonPink, radius: 12)
                            
                            Text("ネオンテトリスの世界へようこそ")
                                .font(.headline)
                                .foregroundColor(NeonColors.neonCyan)
                                .neonGlow(color: NeonColors.neonCyan, radius: 8, intensity: 0.6)
                        }
                        .padding(.bottom)
                        
                        // 遊び方セクション
                        VStack(spacing: 20) {
                            NeonHowToSection(
                                title: "1. ポーズでピース作成",
                                description: "画面の4×3の枠内でポーズを取り、人物の形をテトリスピースに変換します。",
                                icon: "person.fill",
                                glowColor: NeonColors.neonPink
                            )
                            
                            NeonHowToSection(
                                title: "2. ピースを操作",
                                description: "左右移動と回転でピースを配置し、ラインを揃えて消去しましょう。",
                                icon: "gamecontroller.fill",
                                glowColor: NeonColors.neonCyan
                            )
                            
                            NeonHowToSection(
                                title: "3. スコアを稼ごう",
                                description: "IoU（一致度）、安定時間、ライン消去、多様性でスコアが決まります。",
                                icon: "star.fill",
                                glowColor: NeonColors.neonYellow
                            )
                        }
                        
                        // 注意事項
                        VStack(alignment: .leading, spacing: 12) {
                            Text("⚠️ 注意事項")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(NeonColors.neonOrange)
                                .neonGlow(color: NeonColors.neonOrange, radius: 8)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• 無理なポーズは避け、転倒に注意してください")
                                Text("• 周囲の障害物に気をつけてください")
                                Text("• 第三者の写り込みにご配慮ください")
                            }
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                        }
                        .neonCard(glowColor: NeonColors.neonOrange, backgroundColor: NeonColors.deepSpace)
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .background(Circle().fill(NeonColors.spaceBlack))
                        .neonGlow(color: NeonColors.neonPink, radius: 8)
                }
                .padding(.top, 50)
                .padding(.trailing, 20)
            }
        }
    }
}

struct NeonHowToSection: View {
    let title: String
    let description: String
    let icon: String
    let glowColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(glowColor)
                .frame(width: 40, height: 40)
                .neonGlow(color: glowColor, radius: 6, intensity: 0.8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(nil)
            }
        }
        .neonCard(glowColor: glowColor, backgroundColor: NeonColors.spaceBlack)
    }
}

#Preview {
    HomeView()
}