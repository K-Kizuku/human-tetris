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
        NavigationView {
            Form {
                Section("ゲーム設定") {
                    Picker("難易度", selection: $selectedDifficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("難易度の詳細")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let config = QuantizeConfig.presets[selectedDifficulty] {
                            DifficultyDetailView(config: config)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("操作設定") {
                    Picker("操作方法", selection: $inputStyle) {
                        Text("ボタン").tag("buttons")
                        Text("スワイプ").tag("swipe")
                        Text("ボタン + スワイプ").tag("hybrid")
                    }
                    
                    Toggle("ターゲット誘導", isOn: $targetingEnabled)
                    Toggle("ミッション機能", isOn: $missionEnabled)
                }
                
                Section("プライバシー・安全") {
                    Toggle("顔モザイク", isOn: $mosaicEnabled)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("プライバシー保護")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("• すべての処理は端末内で実行されます")
                        Text("• 画像・動画は自動保存されません")
                        Text("• スクリーンショットのみ手動保存可能")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("安全に関するご注意")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        
                        Text("• 無理なポーズは避けてください")
                        Text("• 周囲の障害物に注意してください")
                        Text("• 体調や服装にご配慮ください")
                        Text("• 第三者の写り込みにご配慮ください")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.vertical, 4)
                }
                
                Section("情報") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("対応 iOS")
                        Spacer()
                        Text("18.0+")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                        dismiss()
                    }
                }
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

struct DifficultyDetailView: View {
    let config: QuantizeConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DetailRow(label: "認識閾値", value: String(format: "%.2f", config.theta))
            DetailRow(label: "IoU閾値", value: String(format: "%.2f", config.iou))
            DetailRow(label: "安定時間", value: String(format: "%.1fs", config.stableSec))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Settings.self], inMemory: true)
}