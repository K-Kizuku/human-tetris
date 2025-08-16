//
//  Config.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation

enum Difficulty: String, CaseIterable {
    case easy = "easy"
    case normal = "normal"
    case hard = "hard"
    
    var displayName: String {
        switch self {
        case .easy: return "イージー"
        case .normal: return "ノーマル"
        case .hard: return "ハード"
        }
    }
}

struct QuantizeConfig {
    var theta: Float
    var iou: Float
    var stableSec: Float
    
    static let presets: [Difficulty: QuantizeConfig] = [
        .easy: QuantizeConfig(theta: 0.40, iou: 0.55, stableSec: 0.30),
        .normal: QuantizeConfig(theta: 0.45, iou: 0.60, stableSec: 0.40),
        .hard: QuantizeConfig(theta: 0.50, iou: 0.70, stableSec: 0.50)
    ]
}

struct ScoreWeights {
    var w1: Float = 1.0     // 占有率合計
    var w2: Float = 0.45    // 連結度
    var w3: Float = 0.25    // 予測多様性寄与
    var w4: Float = 0.60    // TargetSpec一致
    var w5: Float = 0.35    // 細長さ罰則
    
    var alpha: Float = 4.0  // ライン消去ボーナス
    var beta: Float = 10.0  // IoU
    var gamma: Float = 3.0  // 安定時間
    var delta: Float = 5.0  // 多様性指数
}

struct GameConfig {
    static let boardWidth = 10
    static let boardHeight = 20
    static let minPieceSize = 3
    static let maxPieceSize = 6
    static let gridRows = 4
    static let gridCols = 3
    
    static let beamWidth = 8
    static let maxBeamWidth = 12
    
    static let aspectRatioThreshold = (slender: 2.0, wide: 1.2)
    
    static let dropInterval: TimeInterval = 1.0
    static let fallAnimationDuration: TimeInterval = 0.3
    static let lineClearAnimationDuration: TimeInterval = 0.4
    static let lockDelay: TimeInterval = 0.5
    
    static let maxRecognitionLatency: TimeInterval = 0.25
    
    static let diversityWindowSize = 8
    static let maxCooldownSteps = 3
    static let cooldownIoUBonus: Float = 0.07
    static let missionIoURelaxation: Float = 0.03
    static let missionMatchBonus: Float = 0.15
}

struct CaptureConfig {
    static let targetFPS = 30
    static let minResolution = 256
    static let maxResolution = 320
    
    static let personSegmentationQuality = 1
    static let enablePoseDetection = true
    
    static let morphologyKernelSize = 3
    static let minConnectedComponentSize = 2
}

struct UIConfig {
    static let roiFrameColor = "blue"
    static let roiFrameOpacity: Double = 0.7
    static let heatmapOpacity: Double = 0.6
    
    static let buttonPadding: Double = 16
    static let buttonHeight: Double = 50
    static let buttonCornerRadius: Double = 8
    
    static let iouBarHeight: Double = 8
    static let stabilityBarHeight: Double = 8
    
    static let ghostOpacity: Double = 0.3
    static let gridLineOpacity: Double = 0.2
}

struct PrivacyConfig {
    static let enableFaceMosaic = false
    static let autoDeleteImages = true
    static let onDeviceProcessingOnly = true
    static let maxStoredScores = 100
}