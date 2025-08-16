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

    /// 表情に応じたテトリス落下速度の倍率
    /// ポジティブな感情ほど遅く（0.8倍）、ネガティブな感情ほど速く（1.5倍）
    var dropSpeedMultiplier: Double {
        switch self {
        case .happy: return 0.8  // 喜び：ゆっくり落下
        case .neutral: return 1.0  // 中立：通常速度
        case .surprised: return 1.2  // 驚き：少し速く
        case .sad: return 1.3  // 悲しみ：速く
        case .angry: return 1.5  // 怒り：最も速く
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
}

class FacialExpressionManager: NSObject, ObservableObject {
    @Published var currentExpression: FacialExpression = .neutral
    @Published var confidence: Float = 0.0
    @Published var isTracking = false
    @Published var isFaceDetected = false
    @Published var isARKitSupported = false

    var delegate: FacialExpressionManagerDelegate?

    private let sessionQueue = DispatchQueue(label: "facial.expression.session.queue")
    private var simulationTimer: Timer?

    // ARKit関連
    private var arSession: ARSession?
    private var arConfiguration: ARFaceTrackingConfiguration?

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
        print("FacialExpressionManager: Starting tracking")

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.isARKitSupported {
                self.startARKitTracking()
            } else {
                print("FacialExpressionManager: ARKit not supported, using simulation mode")
                DispatchQueue.main.async {
                    self.isTracking = true
                    self.isFaceDetected = true
                    self.startSimulation()
                }
            }
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
        guard ARFaceTrackingConfiguration.isSupported else {
            print("FacialExpressionManager: ARKit Face Tracking not supported")
            return
        }

        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1

        arSession = ARSession()
        arSession?.delegate = self

        DispatchQueue.main.async {
            self.arSession?.run(configuration)
            self.isTracking = true
        }

        print("FacialExpressionManager: ARKit Face Tracking started")
    }

    private func analyzeBlendShapes(_ blendShapes: [ARFaceAnchor.BlendShapeLocation: NSNumber]) -> (
        expression: FacialExpression, confidence: Float
    ) {
        // 各表情の特徴的なblendShapeを分析

        // 笑顔の検出
        let mouthSmileLeft = blendShapes[.mouthSmileLeft]?.floatValue ?? 0.0
        let mouthSmileRight = blendShapes[.mouthSmileRight]?.floatValue ?? 0.0
        let _ = blendShapes[.cheekPuff]?.floatValue ?? 0.0  // 将来の拡張用
        let smileIntensity = (mouthSmileLeft + mouthSmileRight) / 2.0

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

        // 閾値を設定（0.3以上で表情として認識）
        let threshold: Float = 0.3

        if let strongest = strongestExpression, strongest.intensity > threshold {
            return (strongest.expression, strongest.intensity)
        } else {
            return (.neutral, 0.8)  // 中立表情
        }
    }

    // MARK: - Simulation Mode (Fallback)

    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
            [weak self] _ in
            self?.simulateExpressionChange()
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
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if anchor is ARFaceAnchor {
                DispatchQueue.main.async {
                    self.isFaceDetected = true
                }
                print("FacialExpressionManager: Face detected")
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let faceAnchor = anchor as? ARFaceAnchor else { continue }

            let blendShapes = faceAnchor.blendShapes
            let (expression, confidence) = analyzeBlendShapes(blendShapes)

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

        DispatchQueue.main.async {
            self.isTracking = false
            self.isFaceDetected = false
        }

        // フォールバックとしてシミュレーションモードに切り替え
        if !isARKitSupported {
            startSimulation()
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
