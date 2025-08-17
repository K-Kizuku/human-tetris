//
//  SettingsView.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [Settings]
    
    @State private var selectedDifficulty: Difficulty = .normal
    @State private var mosaicEnabled = false
    @State private var inputStyle = "buttons"
    @State private var targetingEnabled = true
    @State private var missionEnabled = false
    
    private var currentSettings: Settings {
        settings.first ?? Settings()
    }
    
    var body: some View {
        ZStack {
            // ネオン宇宙背景
            NeonColors.mainBackgroundGradient
                .ignoresSafeArea()
            
            // パーティクル効果背景
            NeonParticleBackground()
            
            NavigationView {
                ScrollView {
                    VStack(spacing: 24) {
                        // ヘッダー
                        VStack(spacing: 16) {
                            Text("設定")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .neonGlow(color: NeonColors.neonCyan, radius: 12, intensity: 1.0)
                            
                            Text("ゲーム体験をカスタマイズ")
                                .font(.headline)
                                .foregroundColor(NeonColors.neonYellow)
                                .neonGlow(color: NeonColors.neonYellow, radius: 6, intensity: 0.8)
                        }
                        .padding(.top, 20)
                        
                        // ゲーム設定セクション
                        NeonSettingsSection(title: "ゲーム設定", icon: "gamecontroller.fill", color: NeonColors.neonPink) {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("難易度")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Picker("難易度", selection: $selectedDifficulty) {
                                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                                            Text(difficulty.displayName).tag(difficulty)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    
                                    if let config = QuantizeConfig.presets[selectedDifficulty] {
                                        NeonDifficultyDetailView(config: config)
                                    }
                                }
                            }
                        }
                        
                        // 操作設定セクション
                        NeonSettingsSection(title: "操作設定", icon: "hand.point.up.left.fill", color: NeonColors.neonCyan) {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("操作方法")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Picker("操作方法", selection: $inputStyle) {
                                        Text("ボタン").tag("buttons")
                                        Text("スワイプ").tag("swipe")
                                        Text("ボタン + スワイプ").tag("hybrid")
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                }
                                
                                NeonToggleRow(title: "ターゲット誘導", isOn: $targetingEnabled, color: NeonColors.neonGreen)
                                NeonToggleRow(title: "ミッション機能", isOn: $missionEnabled, color: NeonColors.neonPurple)
                            }
                        }
                        
                        // プライバシー・安全セクション
                        NeonSettingsSection(title: "プライバシー・安全", icon: "shield.fill", color: NeonColors.neonOrange) {
                            VStack(spacing: 16) {
                                NeonToggleRow(title: "顔モザイク", isOn: $mosaicEnabled, color: NeonColors.neonOrange)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("プライバシー保護")
                                        .font(.headline)
                                        .foregroundColor(NeonColors.neonGreen)
                                        .neonGlow(color: NeonColors.neonGreen, radius: 6)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• すべての処理は端末内で実行されます")
                                        Text("• 画像・動画は自動保存されません")
                                        Text("• スクリーンショットのみ手動保存可能")
                                    }
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.8))
                                }
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("⚠️ 安全に関するご注意")
                                        .font(.headline)
                                        .foregroundColor(NeonColors.neonOrange)
                                        .neonGlow(color: NeonColors.neonOrange, radius: 6)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("• 無理なポーズは避けてください")
                                        Text("• 周囲の障害物に注意してください")
                                        Text("• 体調や服装にご配慮ください")
                                        Text("• 第三者の写り込みにご配慮ください")
                                    }
                                    .font(.body)
                                    .foregroundColor(NeonColors.neonOrange.opacity(0.8))
                                }
                            }
                        }
                        
                        // 情報セクション
                        NeonSettingsSection(title: "情報", icon: "info.circle.fill", color: NeonColors.neonPurple) {
                            VStack(spacing: 12) {
                                NeonInfoRow(label: "バージョン", value: "1.0.0")
                                NeonInfoRow(label: "対応 iOS", value: "18.0+")
                                NeonInfoRow(label: "ギラギラ度", value: "MAX ✨")
                            }
                        }
                        
                        // ボタン
                        HStack(spacing: 16) {
                            Button("キャンセル") {
                                dismiss()
                            }
                            .buttonStyle(NeonTertiaryButtonStyle())
                            
                            Button("保存") {
                                saveSettings()
                                dismiss()
                            }
                            .buttonStyle(NeonPrimaryButtonStyle())
                        }
                        .padding(.bottom, 30)
                    }
                    .padding()
                }
                .navigationBarHidden(true)
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        let current = currentSettings
        selectedDifficulty = Difficulty(rawValue: current.difficulty) ?? .normal
        mosaicEnabled = current.mosaicEnabled
        inputStyle = current.inputStyle
        targetingEnabled = current.targetingEnabled
        missionEnabled = current.missionEnabled
    }
    
    private func saveSettings() {
        let current = currentSettings
        
        current.difficulty = selectedDifficulty.rawValue
        current.mosaicEnabled = mosaicEnabled
        current.inputStyle = inputStyle
        current.targetingEnabled = targetingEnabled
        current.missionEnabled = missionEnabled
        
        if settings.isEmpty {
            modelContext.insert(current)
        }
        
        try? modelContext.save()
    }
}

/// ネオン設定セクション
struct NeonSettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .neonGlow(color: color, radius: 6, intensity: 0.8)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .neonGlow(color: color, radius: 6, intensity: 0.6)
            }
            
            content
        }
        .neonCard(glowColor: color, backgroundColor: NeonColors.spaceBlack)
    }
}

/// ネオントグル行
struct NeonToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: color))
                .neonGlow(color: color, radius: 4, intensity: isOn ? 0.8 : 0.3)
        }
        .padding(.vertical, 4)
    }
}

/// ネオン情報行
struct NeonInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(NeonColors.neonCyan)
                .neonGlow(color: NeonColors.neonCyan, radius: 4, intensity: 0.6)
        }
        .padding(.vertical, 2)
    }
}

/// ネオン難易度詳細表示
struct NeonDifficultyDetailView: View {
    let config: QuantizeConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NeonDetailRow(label: "認識閾値", value: String(format: "%.2f", config.theta), color: NeonColors.neonPink)
            NeonDetailRow(label: "IoU閾値", value: String(format: "%.2f", config.iou), color: NeonColors.neonCyan)
            NeonDetailRow(label: "安定時間", value: String(format: "%.1fs", config.stableSec), color: NeonColors.neonYellow)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(NeonColors.deepSpace.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(NeonColors.neonPink.opacity(0.3), lineWidth: 1)
                )
        )
        .neonGlow(color: NeonColors.neonPink, radius: 6, intensity: 0.4)
    }
}

/// ネオン詳細行
struct NeonDetailRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
                .neonGlow(color: color, radius: 3, intensity: 0.8)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Settings.self], inMemory: true)
}