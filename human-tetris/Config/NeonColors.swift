//
//  NeonColors.swift
//  human-tetris
//
//  Created by Claude Code on 2025/08/17.
//

import SwiftUI

/// ネオン風デザインのカラーパレットとスタイル定義
struct NeonColors {
    // MARK: - メインカラーパレット
    
    /// 鮮やかなネオンピンク/マゼンタ
    static let neonPink = Color(red: 1.0, green: 0.0, blue: 0.8)
    static let neonMagenta = Color(red: 0.9, green: 0.0, blue: 0.6)
    
    /// 鮮やかなシアン/アクア
    static let neonCyan = Color(red: 0.0, green: 1.0, blue: 1.0)
    static let neonAqua = Color(red: 0.0, green: 0.8, blue: 1.0)
    
    /// ネオンパープル
    static let neonPurple = Color(red: 0.6, green: 0.0, blue: 1.0)
    static let deepPurple = Color(red: 0.4, green: 0.0, blue: 0.8)
    
    /// ネオングリーン
    static let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.3)
    static let acidGreen = Color(red: 0.5, green: 1.0, blue: 0.0)
    
    /// ネオンイエロー
    static let neonYellow = Color(red: 1.0, green: 1.0, blue: 0.0)
    static let electricYellow = Color(red: 1.0, green: 0.9, blue: 0.0)
    
    /// ネオンオレンジ
    static let neonOrange = Color(red: 1.0, green: 0.3, blue: 0.0)
    
    /// ネオンブルー
    static let neonBlue = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let electricBlue = Color(red: 0.0, green: 0.7, blue: 1.0)
    
    // MARK: - 背景カラー
    
    /// 深い宇宙色の背景
    static let spaceBlack = Color(red: 0.05, green: 0.05, blue: 0.15)
    static let deepSpace = Color(red: 0.1, green: 0.0, blue: 0.2)
    static let cosmicPurple = Color(red: 0.15, green: 0.0, blue: 0.25)
    
    // MARK: - テトリスブロック専用色
    
    /// テトリスピース用の鮮やかな色
    static let tetrisPink = Color(red: 1.0, green: 0.2, blue: 0.8)
    static let tetrisCyan = Color(red: 0.0, green: 0.9, blue: 1.0)
    static let tetrisPurple = Color(red: 0.7, green: 0.0, blue: 1.0)
    static let tetrisGreen = Color(red: 0.0, green: 1.0, blue: 0.4)
    static let tetrisYellow = Color(red: 1.0, green: 0.95, blue: 0.0)
    static let tetrisOrange = Color(red: 1.0, green: 0.4, blue: 0.0)
    static let tetrisRed = Color(red: 1.0, green: 0.0, blue: 0.3)
    
    // MARK: - グラデーション
    
    /// メイン背景グラデーション（宇宙感）
    static let mainBackgroundGradient = LinearGradient(
        colors: [spaceBlack, deepSpace, cosmicPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// ネオンピンク〜シアンのグラデーション
    static let neonGradient = LinearGradient(
        colors: [neonPink, neonMagenta, neonPurple, neonCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// ゲームボード背景グラデーション
    static let gameBoardGradient = LinearGradient(
        colors: [spaceBlack.opacity(0.8), deepSpace.opacity(0.9)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// ボタン用グラデーション
    static let buttonGradient = LinearGradient(
        colors: [neonPink, neonMagenta],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let secondaryButtonGradient = LinearGradient(
        colors: [neonCyan, neonAqua],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - テキストカラー
    
    /// メインテキスト（白ベース）
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.8)
    static let accentText = neonCyan
    
    /// 警告・エラー
    static let warningText = neonYellow
    static let errorText = neonOrange
    static let criticalText = neonPink
}

/// ネオン効果のモディファイア
struct NeonEffect: ViewModifier {
    let color: Color
    let radius: CGFloat
    let intensity: Double
    
    init(color: Color = NeonColors.neonPink, radius: CGFloat = 10, intensity: Double = 1.0) {
        self.color = color
        self.radius = radius
        self.intensity = intensity
    }
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity * 0.8), radius: radius * 0.5)
            .shadow(color: color.opacity(intensity * 0.6), radius: radius * 0.8)
            .shadow(color: color.opacity(intensity * 0.4), radius: radius * 1.2)
    }
}

extension View {
    /// ネオングロー効果を適用
    func neonGlow(color: Color = NeonColors.neonPink, radius: CGFloat = 10, intensity: Double = 1.0) -> some View {
        self.modifier(NeonEffect(color: color, radius: radius, intensity: intensity))
    }
}

/// ネオンボタンスタイル
struct NeonButtonStyle: ButtonStyle {
    let gradient: LinearGradient
    let glowColor: Color
    
    init(gradient: LinearGradient = NeonColors.buttonGradient, glowColor: Color = NeonColors.neonPink) {
        self.gradient = gradient
        self.glowColor = glowColor
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .font(.headline)
            .fontWeight(.semibold)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(glowColor, lineWidth: 1)
                    )
            )
            .neonGlow(color: glowColor, radius: configuration.isPressed ? 5 : 12, intensity: configuration.isPressed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// ネオンカードスタイル
struct NeonCardStyle: ViewModifier {
    let glowColor: Color
    let backgroundColor: Color
    
    init(glowColor: Color = NeonColors.neonCyan, backgroundColor: Color = NeonColors.spaceBlack) {
        self.glowColor = glowColor
        self.backgroundColor = backgroundColor
    }
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(glowColor, lineWidth: 1)
                    )
            )
            .neonGlow(color: glowColor, radius: 8, intensity: 0.6)
    }
}

extension View {
    /// ネオンカードスタイルを適用
    func neonCard(glowColor: Color = NeonColors.neonCyan, backgroundColor: Color = NeonColors.spaceBlack) -> some View {
        self.modifier(NeonCardStyle(glowColor: glowColor, backgroundColor: backgroundColor))
    }
}

/// アニメーション効果
struct PulsingNeonEffect: ViewModifier {
    let color: Color
    @State private var isPulsing = false
    
    init(color: Color = NeonColors.neonPink) {
        self.color = color
    }
    
    func body(content: Content) -> some View {
        content
            .neonGlow(color: color, radius: isPulsing ? 15 : 8, intensity: isPulsing ? 1.2 : 0.8)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    /// パルシングネオン効果を適用
    func pulsingNeon(color: Color = NeonColors.neonPink) -> some View {
        self.modifier(PulsingNeonEffect(color: color))
    }
}