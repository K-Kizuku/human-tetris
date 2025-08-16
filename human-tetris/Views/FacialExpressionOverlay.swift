//
//  FacialExpressionOverlay.swift
//  human-tetris
//
//  Created by Kiro on 2025/08/17.
//

import SwiftUI

struct FacialExpressionOverlay: View {
    let expression: FacialExpression
    let confidence: Float
    let isFaceDetected: Bool
    let isTracking: Bool
    let currentDropSpeedMultiplier: Double?  // オプショナルで現在の落下速度倍率
    let isARKitSupported: Bool  // ARKitサポート状況

    var body: some View {
        HStack(spacing: 6) {
            // 表情アイコン
            Text(expression.emoji)
                .font(.title3)
                .scaleEffect(isFaceDetected ? 1.1 : 1.0)
                .animation(.bouncy(duration: 0.3), value: isFaceDetected)

            VStack(alignment: .leading, spacing: 2) {
                // 上段：表情名と信頼度
                HStack(spacing: 4) {
                    Text(expression.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text("\(String(format: "%.0f", confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(confidenceColor)

                    // ステータスインジケーター
                    Circle()
                        .fill(statusColor)
                        .frame(width: 4, height: 4)
                        .scaleEffect(isTracking ? 1.0 : 0.6)
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                            value: isTracking)
                }

                // 下段：速度情報（表示される場合のみ）
                if let speedMultiplier = currentDropSpeedMultiplier, confidence >= 0.5 {
                    HStack(spacing: 3) {
                        Image(
                            systemName: speedMultiplier < 1.0
                                ? "tortoise.fill"
                                : speedMultiplier > 1.0 ? "hare.fill" : "equal.circle.fill"
                        )
                        .foregroundColor(speedMultiplierColor)
                        .font(.caption2)

                        Text("\(String(format: "%.1f", speedMultiplier))x")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(speedMultiplierColor)
                    }
                } else {
                    // モード表示（速度情報がない場合）
                    Text(isARKitSupported ? "ARKit" : "シミュレーション")
                        .font(.caption2)
                        .foregroundColor(
                            isARKitSupported ? .green.opacity(0.8) : .orange.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }

    private var confidenceColor: Color {
        switch confidence {
        case 0.7...1.0:
            return .green
        case 0.4..<0.7:
            return .orange
        default:
            return .red
        }
    }

    private var statusColor: Color {
        if !isTracking {
            return .red
        } else if !isFaceDetected {
            return .orange
        } else {
            return .green
        }
    }

    private var statusText: String {
        if !isTracking {
            return "表情認識停止中"
        } else if !isFaceDetected {
            return "顔を検出中..."
        } else {
            return "表情認識中"
        }
    }

    private var speedMultiplierColor: Color {
        guard let speedMultiplier = currentDropSpeedMultiplier else { return .white }

        switch speedMultiplier {
        case ..<1.0:
            return .green  // 遅い（ポジティブ）
        case 1.0:
            return .white  // 通常
        default:
            return .red  // 速い（ネガティブ）
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            FacialExpressionOverlay(
                expression: .happy,
                confidence: 0.85,
                isFaceDetected: true,
                isTracking: true,
                currentDropSpeedMultiplier: 0.8,
                isARKitSupported: true
            )

            FacialExpressionOverlay(
                expression: .neutral,
                confidence: 0.3,
                isFaceDetected: false,
                isTracking: true,
                currentDropSpeedMultiplier: 1.0,
                isARKitSupported: false
            )

            FacialExpressionOverlay(
                expression: .angry,
                confidence: 0.9,
                isFaceDetected: true,
                isTracking: true,
                currentDropSpeedMultiplier: 1.5,
                isARKitSupported: true
            )
        }
        .padding()
    }
}
