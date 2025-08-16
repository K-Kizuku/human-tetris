//
//  IntegratedGameView.swift
//  human-tetris
//
//  Created by Kiro on 2025/08/17.
//

import AVFoundation
import SwiftUI

struct IntegratedGameView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var visionProcessor = VisionProcessor()
    @StateObject private var gameCore = GameCore()
    @StateObject private var facialExpressionManager = FacialExpressionManager()

    @State private var showingResult = false
    @State private var score = 0
    @State private var lines = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var gameTimer: Timer?
    @State private var isGameInitialized = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height

            // レイアウト計算
            let cameraWidth = min(160, screenWidth * 0.35)
            let cameraHeight = min(200, screenHeight * 0.25)
            let gameBoardWidth = min(200, screenWidth * 0.45)
            let gameBoardHeight = min(400, screenHeight * 0.6)

            ZStack {
                // ダイナミック背景
                backgroundView

                VStack(spacing: 0) {
                    // 上部：スコア表示と表情認識
                    topInfoBar
                        .frame(height: 60)

                    // 中央：カメラ映像とゲーム盤面
                    HStack(spacing: 16) {
                        // 左側：背面カメラ映像（ポーズ認識用）
                        VStack(spacing: 12) {
                            Text("ポーズでピース作成")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .cyan, radius: 2)

                            ZStack {
                                // カメラプレビュー
                                CameraPreviewView(cameraManager: cameraManager)
                                    .frame(width: cameraWidth, height: cameraHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [.cyan, .blue, .purple, .cyan],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 3
                                            )
                                            .shadow(color: .cyan, radius: 6)
                                    )

                                // 4×3グリッドオーバーレイ
                                GridOverlayView()
                                    .frame(width: cameraWidth, height: cameraHeight)

                                // 認識状態表示
                                VStack {
                                    Spacer()
                                    HStack {
                                        if visionProcessor.isProcessing {
                                            HStack(spacing: 6) {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                    .tint(.cyan)
                                                Text("認識中...")
                                                    .font(.caption2)
                                                    .foregroundColor(.cyan)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.black.opacity(0.7))
                                            .cornerRadius(8)
                                        }
                                        Spacer()
                                    }
                                    .padding(.bottom, 8)
                                    .padding(.leading, 8)
                                }
                            }

                            // 次のピース情報
                            NextPieceCompactView(nextPiece: gameCore.nextPiecePreview)
                        }

                        // 右側：テトリスゲーム盤面
                        VStack(spacing: 8) {
                            Text("Human Tetris")
                                .font(.headline)
                                .fontWeight(.black)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.cyan, .blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .cyan, radius: 3)

                            ZStack {
                                // ネオンフレーム
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.cyan, .blue, .purple, .pink, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                                    .shadow(color: .cyan, radius: 8)
                                    .shadow(color: .blue, radius: 12)

                                GameBoardView(
                                    gameCore: gameCore,
                                    targetSize: CGSize(
                                        width: gameBoardWidth, height: gameBoardHeight)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                // 次ピース待機表示
                                if gameCore.waitingForNextPiece {
                                    WaitingForPieceOverlay()
                                }
                            }
                            .frame(width: gameBoardWidth, height: gameBoardHeight)
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(maxHeight: .infinity)

                    // 下部：操作ボタン
                    GameControlsCompactView(gameCore: gameCore)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .frame(height: 100)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupGame()
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: gameCore.gameState.gameOver) { _, gameOver in
            if gameOver {
                endGame()
            }
        }
        .onChange(of: gameCore.gameState.score) { _, newScore in
            score = newScore
        }
        .onChange(of: gameCore.gameState.linesCleared) { _, newLines in
            lines = newLines
        }
        .sheet(isPresented: $showingResult) {
            GameResultView(
                finalScore: score,
                linesCleared: lines,
                playTime: elapsedTime,
                onReplay: {
                    restartGame()
                },
                onExit: {
                    dismiss()
                }
            )
        }
    }

    // MARK: - Background View

    private var backgroundView: some View {
        ZStack {
            // ベース背景：ダイナミックグラデーション
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.purple.opacity(0.6),
                    Color.blue.opacity(0.4),
                    Color.cyan.opacity(0.3),
                    Color.black,
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .animation(
                .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                value: elapsedTime
            )

            // アニメーション背景パーティクル
            ForEach(0..<20, id: \.self) { i in
                let colors: [Color] = [.cyan, .purple, .pink, .blue, .green]
                let randomColor = colors[i % colors.count]

                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                randomColor.opacity(0.6),
                                randomColor.opacity(0.3),
                                Color.clear,
                            ]),
                            center: .center,
                            startRadius: 1,
                            endRadius: 20
                        )
                    )
                    .frame(width: CGFloat.random(in: 3...10))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .opacity(0.4)
                    .scaleEffect(sin(elapsedTime + Double(i)) * 0.3 + 1.0)
                    .animation(
                        .easeInOut(duration: Double.random(in: 1.5...3.5))
                            .repeatForever(autoreverses: true),
                        value: elapsedTime
                    )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Info Bar

    private var topInfoBar: some View {
        HStack {
            // 左側：基本情報
            HStack(spacing: 16) {
                CompactInfoItem(title: "SCORE", value: "\(score)", color: .cyan)
                CompactInfoItem(title: "LINES", value: "\(lines)", color: .green)
                CompactInfoItem(title: "TIME", value: formattedTime, color: .yellow)
            }

            Spacer()

            // 右側：表情認識と戻るボタン
            HStack(spacing: 12) {
                // 表情認識表示
                FacialExpressionCompactView(
                    expression: facialExpressionManager.currentExpression,
                    speedMultiplier: gameCore.currentDropSpeedMultiplier
                )

                // 戻るボタン
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .red, radius: 3)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                        .shadow(color: .cyan, radius: 4)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Helper Properties

    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Game Logic

    private func setupGame() {
        print("IntegratedGameView: Setting up game")

        // カメラ設定
        cameraManager.delegate = visionProcessor
        cameraManager.requestPermission()

        // Vision処理設定
        visionProcessor.delegate = self

        // 表情認識設定
        facialExpressionManager.delegate = self
        facialExpressionManager.startTracking()

        // ゲーム開始
        startGame()
    }

    private func startGame() {
        print("IntegratedGameView: Starting game")

        gameCore.startGame()

        // 初期ピースを生成（デフォルトのTピース）
        let initialPiece = Polyomino(cells: [
            GridPosition(x: 1, y: 0),
            GridPosition(x: 0, y: 1),
            GridPosition(x: 1, y: 1),
            GridPosition(x: 2, y: 1),
        ])

        gameCore.spawnPiece(initialPiece, at: 4)

        // ピースプロバイダーを設定
        gameCore.setPieceProvider(visionProcessor)

        startTimer()
        isGameInitialized = true
    }

    private func startTimer() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    private func endGame() {
        gameTimer?.invalidate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showingResult = true
        }
    }

    private func restartGame() {
        gameTimer?.invalidate()
        elapsedTime = 0
        score = 0
        lines = 0
        startGame()
        showingResult = false
    }

    private func cleanup() {
        gameTimer?.invalidate()
        cameraManager.stopSession()
        facialExpressionManager.stopTracking()
    }
}

// MARK: - VisionProcessorDelegate

extension IntegratedGameView: VisionProcessorDelegate {
    func visionProcessor(
        _ processor: VisionProcessor, didGeneratePiece piece: Polyomino,
        withMetrics metrics: PieceGenerationMetrics
    ) {
        print("IntegratedGameView: Generated piece with \(piece.cells.count) cells")
        // ピースは自動的にGameCoreに送信される
    }

    func visionProcessor(_ processor: VisionProcessor, didEncounterError error: Error) {
        print("IntegratedGameView: Vision processing error: \(error)")
    }
}

// MARK: - FacialExpressionManagerDelegate

extension IntegratedGameView: FacialExpressionManagerDelegate {
    func facialExpressionManager(
        _ manager: FacialExpressionManager, didDetectExpression result: FacialExpressionResult
    ) {
        gameCore.updateDropSpeedForExpression(result.expression, confidence: result.confidence)
    }

    func facialExpressionManager(_ manager: FacialExpressionManager, didEncounterError error: Error)
    {
        print("IntegratedGameView: Facial expression error: \(error)")
    }
}

// MARK: - Supporting Views

struct CompactInfoItem: View {
    let title: String
    let value: String
    let color: Color
    @State private var glowIntensity = false

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.8), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: color, radius: 1)

            Text(value)
                .font(.caption)
                .fontWeight(.black)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: color, radius: glowIntensity ? 2 : 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowIntensity = true
            }
        }
    }
}

struct FacialExpressionCompactView: View {
    let expression: FacialExpression?
    let speedMultiplier: Double?
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        if let expression = expression, let speedMultiplier = speedMultiplier,
            speedMultiplier != 1.0
        {
            HStack(spacing: 6) {
                Text(expression.rawValue)
                    .font(.title3)
                    .scaleEffect(pulseScale)

                Text("×\(String(format: "%.1f", speedMultiplier))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
                    )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                }
            }
        }
    }
}

struct NextPieceCompactView: View {
    let nextPiece: Polyomino?

    var body: some View {
        VStack(spacing: 6) {
            Text("NEXT")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .cyan, radius: 1)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.8))
                    .frame(width: 50, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                    )

                if let piece = nextPiece {
                    NextPiecePreviewCompact(piece: piece)
                } else {
                    Text("?")
                        .font(.title3)
                        .foregroundColor(.cyan)
                }
            }
        }
    }
}

struct NextPiecePreviewCompact: View {
    let piece: Polyomino

    var body: some View {
        let cellSize: CGFloat = 6

        ForEach(Array(piece.cells.enumerated()), id: \.offset) { _, cell in
            Rectangle()
                .fill(Color.cyan)
                .frame(width: cellSize, height: cellSize)
                .position(
                    x: CGFloat(cell.x) * cellSize + cellSize / 2 + 25,
                    y: CGFloat(cell.y) * cellSize + cellSize / 2 + 20
                )
        }
    }
}

struct GameControlsCompactView: View {
    @ObservedObject var gameCore: GameCore

    var body: some View {
        HStack(spacing: 20) {
            // 左移動
            CompactGameButton(
                icon: "arrowshape.left.fill",
                action: { _ = gameCore.movePiece(dx: -1) }
            )

            // 回転
            CompactGameButton(
                icon: "arrow.clockwise",
                action: { _ = gameCore.rotatePiece() }
            )

            // 右移動
            CompactGameButton(
                icon: "arrowshape.right.fill",
                action: { _ = gameCore.movePiece(dx: 1) }
            )

            Spacer()

            // ハードドロップ
            CompactGameButton(
                icon: "arrowshape.down.fill",
                action: { gameCore.hardDrop() },
                color: .orange
            )

            // ポーズ/再開
            CompactGameButton(
                icon: gameCore.isGameRunning ? "pause.fill" : "play.fill",
                action: {
                    if gameCore.isGameRunning {
                        gameCore.pauseGame()
                    } else {
                        gameCore.resumeGame()
                    }
                },
                color: .purple
            )
        }
    }
}

struct CompactGameButton: View {
    let icon: String
    let action: () -> Void
    let color: Color

    init(icon: String, action: @escaping () -> Void, color: Color = .cyan) {
        self.icon = icon
        self.action = action
        self.color = color
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(0.8),
                                color.opacity(0.4),
                                Color.black.opacity(0.8),
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 2)
                            .shadow(color: color, radius: 3)
                    )

                Image(systemName: icon)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, color],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: color, radius: 2)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GridOverlayView: View {
    var body: some View {
        ZStack {
            // 4×3グリッド線
            Path { path in
                let cellWidth: CGFloat = 40
                let cellHeight: CGFloat = 50

                // 縦線
                for i in 0...4 {
                    let x = CGFloat(i) * cellWidth
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: cellHeight * 3))
                }

                // 横線
                for i in 0...3 {
                    let y = CGFloat(i) * cellHeight
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: cellWidth * 4, y: y))
                }
            }
            .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
            .frame(width: 160, height: 150)

            // グリッド説明
            VStack {
                Spacer()
                Text("4×3 グリッド")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(.bottom, 4)
            }
        }
    }
}

#Preview {
    IntegratedGameView()
}
