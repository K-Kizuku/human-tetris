//
//  FacialExpressionManager.swift
//  human-tetris
//
//  Created by Kiro on 2025/08/17.
//

import ARKit
import Combine
import SwiftUI

// 表情の種類を定義
enum FacialExpression: String, CaseIterable {
    case neutral = "中立"
    case happy = "喜び"
    case angry = "怒り"
    case surprised = "驚き"
    case sad = "悲しみ"

    var emoji: String {
        switch self {
        case .neutral: return "😐"
        case .happy: return "😊"
        case .angry: return "😠"
        case .surprised: return "😲"
        case .sad: return "😢"
        }
    }

    /// 表情に応じたテトリス落下間隔の倍率
    /// ポジティブな感情ほど遅く（間隔を長く）、ネガティブな感情ほど速く（間隔を短く）
    var dropSpeedMultiplier: Double {
        switch self {
        case .happy: return 1.25  // 喜び：ゆっくり落下（間隔を長く）
        case .neutral: return 1.0  // 中立：通常速度
        case .surprised: return 0.83  // 驚き：少し速く（間隔を短く）
        case .sad: return 0.77  // 悲しみ：速く（間隔を短く）
        case .angry: return 0.67  // 怒り：最も速く（間隔を短く）
        }
    }

    /// 表情の感情的な極性（ポジティブ/ネガティブ）
    var emotionalPolarity: String {
        switch self {
        case .happy: return "ポジティブ"
        case .neutral: return "中立"
        case .surprised: return "中立"
        case .sad: return "ネガティブ"
        case .angry: return "ネガティブ"
        }
    }
}

// 表情認識の結果を表すデータ構造
struct FacialExpressionResult {
    let expression: FacialExpression
    let confidence: Float
    let timestamp: Date
}

protocol FacialExpressionManagerDelegate {
    func facialExpressionManager(
        _ manager: FacialExpressionManager, didDetectExpression result: FacialExpressionResult)
    func facialExpressionManager(_ manager: FacialExpressionManager, didEncounterError error: Error)
    // 統合ARSessionから背面カメラフレームを提供
    func facialExpressionManager(
        _ manager: FacialExpressionManager, didOutputBackCameraFrame pixelBuffer: CVPixelBuffer)
}

class FacialExpressionManager: NSObject, ObservableObject {
    @Published var currentExpression: FacialExpression = .neutral
    @Published var confidence: Float = 0.0
    @Published var isTracking = false
    @Published var isFaceDetected = false
    @Published var isARKitSupported = false
    @Published var currentBackCameraFrame: CVPixelBuffer?

    var delegate: FacialExpressionManagerDelegate?

    private let sessionQueue = DispatchQueue(label: "facial.expression.session.queue")
    private var simulationTimer: Timer?

    // ARKit関連
    private var arSession: ARSession?
    private var arConfiguration: ARFaceTrackingConfiguration?
    
    // 表情認識更新頻度制限（1秒に2回 = 500ms間隔）
    private var lastExpressionUpdateTime: Date = Date.distantPast
    private let minUpdateInterval: TimeInterval = 0.5  // 500ms
    
    // 背面カメラフレーム配信用の頻度制限（30fps -> 15fps に調整）
    private var lastBackCameraFrameTime: Date = Date.distantPast
    private let backCameraFrameInterval: TimeInterval = 1.0 / 15.0  // 15fps

    override init() {
        super.init()
        checkARKitSupport()
        print("FacialExpressionManager: Initialized with ARKit support: \(isARKitSupported)")
    }

    deinit {
        stopTracking()
    }

    private func checkARKitSupport() {
        isARKitSupported = ARFaceTrackingConfiguration.isSupported
        print("FacialExpressionManager: ARKit Face Tracking supported: \(isARKitSupported)")
    }

    func startTracking() {
        print("FacialExpressionManager: Starting ARKit based tracking")

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            #if targetEnvironment(simulator)
            print("FacialExpressionManager: Running in simulator, using simulation mode")
            DispatchQueue.main.async {
                self.startSimulation()
            }
            #else
            if self.isARKitSupported {
                print("FacialExpressionManager: Attempting ARKit tracking")
                
                // ARKitトラッキングを開始
                self.startARKitTracking()
                
                // 5秒後にARKitが動作していない場合はシミュレーションモードに切り替え
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if !self.isFaceDetected && self.isTracking {
                        print("FacialExpressionManager: ARKit timeout, falling back to simulation")
                        self.arSession?.pause()
                        self.arSession = nil
                        self.startSimulation()
                    }
                }
            } else {
                print("FacialExpressionManager: ARKit not supported, using simulation mode")
                DispatchQueue.main.async {
                    self.startSimulation()
                }
            }
            #endif
        }
    }

    func stopTracking() {
        print("FacialExpressionManager: Stopping tracking")

        sessionQueue.async { [weak self] in
            // ARKitセッションを停止
            self?.arSession?.pause()
            self?.arSession = nil

            // シミュレーションタイマーを停止
            self?.simulationTimer?.invalidate()
            self?.simulationTimer = nil

            DispatchQueue.main.async {
                self?.isTracking = false
                self?.isFaceDetected = false
                self?.currentExpression = .neutral
                self?.confidence = 0.0
            }
        }
    }

    // MARK: - ARKit Face Tracking

    private func startARKitTracking() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("FacialExpressionManager: ARKit World Tracking not supported")
            DispatchQueue.main.async {
                self.startSimulation()
            }
            return
        }

        // ARKit一本化: ARWorldTrackingConfigurationでuserFaceTrackingEnabledを使用
        let configuration = ARWorldTrackingConfiguration()
        
        // Apple公式の推奨アプローチ: 背面（ワールドトラッキング）+ 前面（フェイストラッキング）を同一ARSessionで
        if #available(iOS 13.0, *) {
            configuration.userFaceTrackingEnabled = true
            print("FacialExpressionManager: Using ARWorldTrackingConfiguration with userFaceTrackingEnabled")
        } else {
            // iOS 13未満では従来のARFaceTrackingConfigurationを使用
            print("FacialExpressionManager: iOS 13未満のため、ARFaceTrackingConfigurationを使用")
            let faceConfig = ARFaceTrackingConfiguration()
            faceConfig.maximumNumberOfTrackedFaces = 1
            
            arSession = ARSession()
            arSession?.delegate = self
            arSession?.delegateQueue = DispatchQueue(label: "arkit.session.queue", qos: .userInitiated)
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.arSession?.run(faceConfig, options: [.resetTracking, .removeExistingAnchors])
                DispatchQueue.main.async {
                    self.isTracking = true
                    print("FacialExpressionManager: ARFaceTrackingConfiguration session started")
                }
            }
            return
        }
        
        // planeDetectionは無効化してリソース節約
        configuration.planeDetection = []
        
        // フレームレートを最適化
        if let videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: { format in
            format.framesPerSecond == 30 && format.imageResolution.width <= 1280
        }) {
            configuration.videoFormat = videoFormat
            print("FacialExpressionManager: Using optimized video format: \(videoFormat.imageResolution)@\(videoFormat.framesPerSecond)fps")
        }

        arSession = ARSession()
        arSession?.delegate = self
        arSession?.delegateQueue = DispatchQueue(label: "unified.arkit.session.queue", qos: .userInitiated)

        print("FacialExpressionManager: Starting unified ARKit session (World + Face tracking)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
            self.arSession?.run(configuration, options: options)
            DispatchQueue.main.async {
                self.isTracking = true
                print("FacialExpressionManager: Unified ARKit session started successfully")
            }
        }
    }

    private func analyzeBlendShapes(_ blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) -> (
        expression: FacialExpression, confidence: Float
    ) {
        // 各表情の特徴的なblendShapeを分析

        // 笑顔の検出（より敏感に）
        let mouthSmileLeft = blendShapes[.mouthSmileLeft]?.floatValue ?? 0.0
        let mouthSmileRight = blendShapes[.mouthSmileRight]?.floatValue ?? 0.0
        let cheekPuff = blendShapes[.cheekPuff]?.floatValue ?? 0.0
        let mouthDimpleLeft = blendShapes[.mouthDimpleLeft]?.floatValue ?? 0.0
        let mouthDimpleRight = blendShapes[.mouthDimpleRight]?.floatValue ?? 0.0
        
        // 複数の笑顔指標を組み合わせて適度な感度向上
        let baseSmile = (mouthSmileLeft + mouthSmileRight) / 2.0
        let additionalSmileFeatures = (cheekPuff + mouthDimpleLeft + mouthDimpleRight) / 3.0
        let smileIntensity = baseSmile + (additionalSmileFeatures * 0.3)  // 追加特徴量を30%の重みで加算（中間レベル）
        
        // デバッグログ：スマイル検出の詳細（閾値近辺のみ）
        if smileIntensity > 0.10 {
            print("FacialExpressionManager: Smile detection - base: \(String(format: "%.3f", baseSmile)), additional: \(String(format: "%.3f", additionalSmileFeatures)), total: \(String(format: "%.3f", smileIntensity))")
        }

        // 怒りの検出
        let browDownLeft = blendShapes[.browDownLeft]?.floatValue ?? 0.0
        let browDownRight = blendShapes[.browDownRight]?.floatValue ?? 0.0
        let mouthFrownLeft = blendShapes[.mouthFrownLeft]?.floatValue ?? 0.0
        let mouthFrownRight = blendShapes[.mouthFrownRight]?.floatValue ?? 0.0
        let angerIntensity = (browDownLeft + browDownRight + mouthFrownLeft + mouthFrownRight) / 4.0

        // 驚きの検出
        let browInnerUp = blendShapes[.browInnerUp]?.floatValue ?? 0.0
        let eyeWideLeft = blendShapes[.eyeWideLeft]?.floatValue ?? 0.0
        let eyeWideRight = blendShapes[.eyeWideRight]?.floatValue ?? 0.0
        let jawOpen = blendShapes[.jawOpen]?.floatValue ?? 0.0
        let surpriseIntensity = (browInnerUp + eyeWideLeft + eyeWideRight + jawOpen) / 4.0

        // 悲しみの検出
        let mouthLowerDownLeft = blendShapes[.mouthLowerDownLeft]?.floatValue ?? 0.0
        let mouthLowerDownRight = blendShapes[.mouthLowerDownRight]?.floatValue ?? 0.0
        let browOuterUpLeft = blendShapes[.browOuterUpLeft]?.floatValue ?? 0.0
        let browOuterUpRight = blendShapes[.browOuterUpRight]?.floatValue ?? 0.0
        let sadnessIntensity =
            (mouthLowerDownLeft + mouthLowerDownRight + browOuterUpLeft + browOuterUpRight) / 4.0

        // 最も強い表情を決定
        let intensities: [(expression: FacialExpression, intensity: Float)] = [
            (.happy, smileIntensity),
            (.angry, angerIntensity),
            (.surprised, surpriseIntensity),
            (.sad, sadnessIntensity),
        ]

        let strongestExpression = intensities.max { $0.intensity < $1.intensity }

        // 閾値を設定（中間レベル：適度な感度で表情認識）
        let generalThreshold: Float = 0.22  // 元0.3と現0.15の中間
        let smileThreshold: Float = 0.12    // 元0.3と現0.08の中間レベル

        if let strongest = strongestExpression {
            let applicableThreshold = (strongest.expression == .happy) ? smileThreshold : generalThreshold
            
            if strongest.intensity > applicableThreshold {
                // 信頼度を向上させる計算：より高い値を出力
                var enhancedConfidence: Float
                
                if strongest.expression == .happy {
                    // スマイルの場合は適度に感度を上げる（中間レベル）
                    enhancedConfidence = min(1.0, strongest.intensity * 2.0 + 0.2)  // スマイルは2.2倍＋0.2のベース値
                } else {
                    enhancedConfidence = min(1.0, strongest.intensity * 2.0 + 0.2)   // その他は2.0倍＋0.2のベース値
                }
                
                return (strongest.expression, enhancedConfidence)
            } else {
                return (.neutral, 0.8)  // 中立表情
            }
        } else {
            return (.neutral, 0.8)  // 表情が検出されない場合
        }
    }

    // MARK: - Simulation Mode (Fallback)

    private func startSimulation() {
        print("FacialExpressionManager: Starting simulation mode")
        DispatchQueue.main.async {
            self.isTracking = true
            self.isFaceDetected = true
            
            // 最初の表情を即座に設定
            self.simulateExpressionChange()
            
            // 定期的な表情変化タイマーを開始
            self.simulationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) {
                [weak self] _ in
                self?.simulateExpressionChange()
            }
        }
    }

    private func simulateExpressionChange() {
        let expressions: [FacialExpression] = [.neutral, .happy, .angry, .surprised, .sad]
        let randomExpression = expressions.randomElement() ?? .neutral
        let randomConfidence = Float.random(in: 0.3...0.9)

        DispatchQueue.main.async {
            self.currentExpression = randomExpression
            self.confidence = randomConfidence

            let result = FacialExpressionResult(
                expression: randomExpression,
                confidence: randomConfidence,
                timestamp: Date()
            )

            self.delegate?.facialExpressionManager(self, didDetectExpression: result)
        }
    }
}

// MARK: - ARSessionDelegate

extension FacialExpressionManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // フレームレート調整: 15fpsに制限して処理負荷を軽減
        let now = Date()
        guard now.timeIntervalSince(lastBackCameraFrameTime) >= backCameraFrameInterval else {
            return
        }
        lastBackCameraFrameTime = now
        
        // 統合ARSessionから背面カメラフレームを取得
        let pixelBuffer = frame.capturedImage
        
        // UIスレッドで現在のフレームを更新（プレビュー表示用）
        DispatchQueue.main.async { [weak self] in
            self?.currentBackCameraFrame = pixelBuffer
        }
        
        // Vision処理のためにデリゲートにフレームを送信
        delegate?.facialExpressionManager(self, didOutputBackCameraFrame: pixelBuffer)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARFaceAnchor {
                DispatchQueue.main.async {
                    self.isFaceDetected = true
                }
                print("FacialExpressionManager: Face detected via unified ARSession")
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // 更新頻度制限：1秒に2回まで（500ms間隔）
        let now = Date()
        guard now.timeIntervalSince(lastExpressionUpdateTime) >= minUpdateInterval else {
            return // スキップして背面カメラのリソースを節約
        }
        
        for anchor in anchors {
            guard let faceAnchor = anchor as? ARFaceAnchor else { continue }

            let blendShapes = faceAnchor.blendShapes
            let (expression, confidence) = analyzeBlendShapes(blendShapes)

            print("FacialExpressionManager: Detected expression: \(expression.rawValue) with confidence: \(confidence)")

            // 更新時刻を記録
            lastExpressionUpdateTime = now

            DispatchQueue.main.async {
                self.currentExpression = expression
                self.confidence = confidence
                self.isFaceDetected = true

                let result = FacialExpressionResult(
                    expression: expression,
                    confidence: confidence,
                    timestamp: Date()
                )

                self.delegate?.facialExpressionManager(self, didDetectExpression: result)
            }
            
            // 一つのアンカーのみ処理してリソース節約
            break
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARFaceAnchor {
                DispatchQueue.main.async {
                    self.isFaceDetected = false
                    self.currentExpression = .neutral
                    self.confidence = 0.0
                }
                print("FacialExpressionManager: Face lost")
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("FacialExpressionManager: ARSession failed with error: \(error)")
        
        // カメラリソースの競合エラーの場合は詳細をログ出力
        if let arError = error as? ARError {
            switch arError.code {
            case .cameraUnauthorized:
                print("FacialExpressionManager: Camera unauthorized")
            case .unsupportedConfiguration:
                print("FacialExpressionManager: Unsupported configuration")
            case .invalidReferenceImage:
                print("FacialExpressionManager: Invalid reference image")
            default:
                print("FacialExpressionManager: ARError: \(arError.localizedDescription)")
            }
        }

        DispatchQueue.main.async {
            self.isTracking = false
            self.isFaceDetected = false
        }

        // エラーの場合は常にシミュレーションモードに切り替え
        print("FacialExpressionManager: Falling back to simulation mode due to error")
        DispatchQueue.main.async {
            self.startSimulation()
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("FacialExpressionManager: ARSession was interrupted")
        DispatchQueue.main.async {
            self.isTracking = false
        }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("FacialExpressionManager: ARSession interruption ended")
        DispatchQueue.main.async {
            self.isTracking = true
        }
    }
}
