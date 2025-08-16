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
        HStack(spacing: 8) {
            // 表情アイコン（ネオン効果）
            Text(expression.emoji)
                .font(.title2)
                .scaleEffect(isFaceDetected ? 1.2 : 1.0)
                .shadow(color: .white, radius: isFaceDetected ? 4 : 0)
                .animation(.bouncy(duration: 0.3), value: isFaceDetected)

            VStack(alignment: .leading, spacing: 3) {
                // 上段：表情名と信頼度
                HStack(spacing: 6) {
                    Text(expression.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .cyan, radius: 1)

                    Text("\(String(format: "%.0f", confidence * 100))%")
                        .font(.caption2)
                        .fontWeight(.black)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [confidenceColor, .white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: confidenceColor, radius: 2)

                    // ステータスインジケーター（パルス効果）
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [statusColor, statusColor.opacity(0.3)],
                                center: .center,
                                startRadius: 1,
                                endRadius: 4
                            )
                        )
                        .frame(width: 6, height: 6)
                        .scaleEffect(isTracking ? 1.2 : 0.8)
                        .shadow(color: statusColor, radius: isTracking ? 3 : 1)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                            value: isTracking)
                }

                // 下段：速度情報（表示される場合のみ）
                if let speedMultiplier = currentDropSpeedMultiplier, confidence >= 0.5 {
                    HStack(spacing: 4) {
                        Image(
                            systemName: speedMultiplier < 1.0
                                ? "tortoise.fill"
                                : speedMultiplier > 1.0 ? "hare.fill" : "equal.circle.fill"
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: speedMultiplier < 1.0 ? [.green, .mint] : [.red, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .font(.caption)
                        .shadow(color: speedMultiplierColor, radius: 2)

                        Text("\(String(format: "%.1f", speedMultiplier))x")
                            .font(.caption2)
                            .fontWeight(.black)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [speedMultiplierColor, .white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: speedMultiplierColor, radius: 1)
                    }
                } else {
                    // モード表示（速度情報がない場合）
                    Text(isARKitSupported ? "ARKit" : "シミュレーション")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: isARKitSupported ? [.green, .mint] : [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(
                            color: isARKitSupported ? .green : .orange,
                            radius: 1
                        )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            ZStack {
                // ベース背景
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.9),
                                Color.purple.opacity(0.4),
                                Color.black.opacity(0.9),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // ネオンボーダー
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple, .pink, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .shadow(color: .cyan, radius: 3)
            }
        )
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
