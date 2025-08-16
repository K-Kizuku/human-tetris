//
//  GameView.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI

struct GameView: View {
    @ObservedObject var gameCore: GameCore
    let initialPiece: Polyomino
    let pieceProvider: GamePieceProvider?

    @State private var boardScale: CGFloat = 0.8
    @State private var showingResult = false
    @State private var score = 0
    @State private var lines = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var gameTimer: Timer?

    // 表情認識マネージャー
    @StateObject private var facialExpressionManager = FacialExpressionManager()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height

            // レイアウト計算（高さを考慮した調整）
            let maxGameBoardWidth = min(220, screenWidth * 0.6)
            let sideWidth = max(50, min(70, (screenWidth - maxGameBoardWidth) / 2 * 0.8))
            let spacing = max(6, min(16, screenWidth * 0.025))

            // 利用可能な高さを計算
            let topBarHeight: CGFloat = 50
            let controlsHeight: CGFloat = min(120, screenHeight * 0.12)
            let availableHeight = screenHeight - topBarHeight - controlsHeight - 40  // マージン
            let gameBoardHeight = min(400, availableHeight * 0.8)

            VStack(spacing: 0) {
                // 上部：スコア表示と表情認識を統合
                ZStack {
                    // スコア表示（背景）
                    GameInfoBar(
                        score: score,
                        lines: lines,
                        time: elapsedTime,
                        gameOver: gameCore.gameState.gameOver,
                        dropSpeedMultiplier: gameCore.currentDropSpeedMultiplier
                    )
                    .frame(height: topBarHeight)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.8),
                                Color.blue.opacity(0.6),
                                Color.cyan.opacity(0.4),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                    // 表情認識オーバーレイ（右上に配置）
                    HStack {
                        Spacer()

                        FacialExpressionOverlay(
                            expression: facialExpressionManager.currentExpression,
                            confidence: facialExpressionManager.confidence,
                            isFaceDetected: facialExpressionManager.isFaceDetected,
                            isTracking: facialExpressionManager.isTracking,
                            currentDropSpeedMultiplier: gameCore.currentDropSpeedMultiplier,
                            isARKitSupported: facialExpressionManager.isARKitSupported
                        )
                        .frame(maxWidth: min(180, screenWidth * 0.4))
                        .padding(.trailing, 8)
                        .padding(.top, 4)
                    }
                }

                // 中央：ゲーム盤面
                HStack(spacing: spacing) {
                    // 左側：次のピース情報
                    VStack(spacing: 8) {
                        NextPieceView(nextPiece: gameCore.nextPiecePreview)

                        LevelIndicator(
                            level: gameCore.gameState.level,
                            progress: Double(lines % 10) / 10.0
                        )

                        Spacer()
                    }
                    .frame(width: sideWidth)

                    // 中央：ゲーム盤（ネオンフレーム付き）
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
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: elapsedTime)

                        GameBoardView(
                            gameCore: gameCore,
                            targetSize: CGSize(
                                width: maxGameBoardWidth, height: gameBoardHeight)
                        )
                        .scaleEffect(boardScale)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // 次ピース待機表示
                        if gameCore.waitingForNextPiece {
                            WaitingForPieceOverlay()
                        }
                    }
                    .frame(width: maxGameBoardWidth, height: gameBoardHeight)

                    // 右側：統計情報
                    VStack(spacing: 8) {
                        StatsView(gameState: gameCore.gameState)

                        Spacer()
                    }
                    .frame(width: sideWidth)
                }
                .padding(.horizontal, max(6, screenWidth * 0.015))
                .frame(maxHeight: .infinity)

                // 下部：操作ボタン
                GameControlsView(gameCore: gameCore)
                    .padding(.horizontal, max(6, screenWidth * 0.015))
                    .padding(.bottom, 20)
                    .frame(height: controlsHeight)

                // 緊急用フォールバック表示（コンパクト）
                if gameCore.gameState.currentPiece == nil {
                    HStack {
                        Text("INITIALIZING...")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.3))
                }
            }
        }
        .background(
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
                    .easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: elapsedTime)

                // アニメーション背景パーティクル（より鮮やか）
                ForEach(0..<25, id: \.self) { i in
                    let colors: [Color] = [.cyan, .purple, .pink, .blue, .green]
                    let randomColor = colors[i % colors.count]

                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    randomColor.opacity(0.8),
                                    randomColor.opacity(0.4),
                                    Color.clear,
                                ]),
                                center: .center,
                                startRadius: 1,
                                endRadius: 25
                            )
                        )
                        .frame(width: CGFloat.random(in: 3...12))
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

                // グリッド背景
                Path { path in
                    let spacing: CGFloat = 30
                    let width = UIScreen.main.bounds.width
                    let height = UIScreen.main.bounds.height

                    // 縦線
                    for i in stride(from: 0, through: width, by: spacing) {
                        path.move(to: CGPoint(x: i, y: 0))
                        path.addLine(to: CGPoint(x: i, y: height))
                    }

                    // 横線
                    for i in stride(from: 0, through: height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: i))
                        path.addLine(to: CGPoint(x: width, y: i))
                    }
                }
                .stroke(Color.cyan.opacity(0.1), lineWidth: 0.5)
            }
            .ignoresSafeArea()
        )
        .onAppear {
            startGame()
            startFacialExpressionTracking()
        }
        .onDisappear {
            gameTimer?.invalidate()
            facialExpressionManager.stopTracking()
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

    private func startGame() {
        print("GameView: startGame() called")
        print(
            "GameView: Initial piece has \(initialPiece.cells.count) cells: \(initialPiece.cells)")

        // ゲームを先に開始
        print("GameView: Calling gameCore.startGame()")
        gameCore.startGame()
        print("GameView: gameCore.startGame() completed, isGameRunning = \(gameCore.isGameRunning)")

        let spawnColumn = Int(Double.random(in: 0...9))
        print("GameView: Spawning initial piece at column \(spawnColumn)")
        gameCore.spawnPiece(initialPiece, at: spawnColumn)
        print("GameView: Piece spawning completed")

        print("GameView: Starting timer")
        startTimer()
        print("GameView: Timer started")

        // ピースプロバイダーを非同期で設定
        if let provider = pieceProvider {
            print("GameView: Setting piece provider asynchronously")
            DispatchQueue.main.async {
                self.gameCore.setPieceProvider(provider)
                print("GameView: Piece provider set successfully")
            }
        } else {
            print("GameView: Warning - No piece provider available")
        }

        print("GameView: startGame() completed successfully")
    }

    private func startFacialExpressionTracking() {
        print("GameView: Starting facial expression tracking")
        facialExpressionManager.delegate = self
        facialExpressionManager.startTracking()
    }

    private func startTimer() {
        // 既存のタイマーを停止
        gameTimer?.invalidate()
        gameTimer = nil

        print("GameView: Starting elapsed time timer")
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

}

// MARK: - FacialExpressionManagerDelegate

extension GameView: FacialExpressionManagerDelegate {
    func facialExpressionManager(
        _ manager: FacialExpressionManager, didDetectExpression result: FacialExpressionResult
    ) {
        // 表情認識の結果をGameCoreに伝達
        print(
            "GameView: Detected expression: \(result.expression.rawValue) with confidence: \(result.confidence)"
        )
        gameCore.updateDropSpeedForExpression(result.expression, confidence: result.confidence)
    }

    func facialExpressionManager(_ manager: FacialExpressionManager, didEncounterError error: Error)
    {
        print("GameView: Facial expression error: \(error)")
    }
}

struct GameInfoBar: View {
    let score: Int
    let lines: Int
    let time: TimeInterval
    let gameOver: Bool
    let dropSpeedMultiplier: Double?  // 落下速度倍率（オプショナル）

    @State private var glowAnimation = false

    private var formattedTime: String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack {
            // 左側：基本情報（ネオンスタイル）
            HStack(spacing: 20) {
                NeonInfoItem(title: "SCORE", value: "\(score)", color: .cyan)
                NeonInfoItem(title: "LINES", value: "\(lines)", color: .green)
                NeonInfoItem(title: "TIME", value: formattedTime, color: .yellow)
            }

            Spacer()

            // 右側：ゲーム状態
            if gameOver {
                Text("GAME OVER")
                    .font(.headline)
                    .fontWeight(.black)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .red, radius: glowAnimation ? 10 : 5)
                    .scaleEffect(glowAnimation ? 1.1 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: glowAnimation
                    )
                    .onAppear { glowAnimation = true }
            } else if let speedMultiplier = dropSpeedMultiplier, speedMultiplier != 1.0 {
                HStack(spacing: 6) {
                    Image(systemName: speedMultiplier < 1.0 ? "tortoise.fill" : "hare.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: speedMultiplier < 1.0 ? [.green, .mint] : [.red, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .font(.title3)
                        .shadow(
                            color: speedMultiplier < 1.0 ? .green : .red,
                            radius: 4
                        )

                    Text("\(String(format: "%.1f", speedMultiplier))x")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .cyan],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .cyan, radius: 2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    LinearGradient(
                                        colors: [.cyan, .blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            ZStack {
                // ベース背景
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.8),
                                Color.purple.opacity(0.3),
                                Color.black.opacity(0.8),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // ネオンボーダー
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: .cyan, radius: 4)
            }
        )
    }
}

struct NeonInfoItem: View {
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
                .shadow(color: color, radius: glowIntensity ? 3 : 1)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: glowIntensity
                )
        }
        .onAppear {
            glowIntensity = true
        }
    }
}

struct NextPieceView: View {
    let nextPiece: Polyomino?
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 8) {
            Text("NEXT")
                .font(.caption)
                .fontWeight(.black)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .cyan, radius: 1)

            ZStack {
                // ベース背景
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.8),
                                Color.blue.opacity(0.3),
                                Color.black.opacity(0.8),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                // ネオンボーダー
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .cyan, radius: glowPulse ? 4 : 2)

                // コンテンツ
                Group {
                    if let piece = nextPiece {
                        NextPiecePreview(piece: piece)
                    } else {
                        Text("?")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .cyan],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .cyan, radius: 2)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

struct NextPiecePreview: View {
    let piece: Polyomino

    var body: some View {
        let cellSize: CGFloat = 8

        ForEach(Array(piece.cells.enumerated()), id: \.offset) { _, cell in
            Rectangle()
                .fill(Color.cyan)
                .frame(width: cellSize, height: cellSize)
                .position(
                    x: CGFloat(cell.x) * cellSize + cellSize / 2 + 30,
                    y: CGFloat(cell.y) * cellSize + cellSize / 2 + 30
                )
        }
    }
}

struct WaitingForPieceOverlay: View {
    @State private var animationPhase: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("次のピースを待機中...")
                .font(.headline)
                .foregroundColor(.white)
                .opacity(0.7 + 0.3 * sin(animationPhase))
        }
        .padding(20)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                animationPhase = .pi * 2
            }
        }
    }
}

struct LevelIndicator: View {
    let level: Int
    let progress: Double
    @State private var energyPulse = false

    var body: some View {
        VStack(spacing: 8) {
            Text("LV.\(level)")
                .font(.caption)
                .fontWeight(.black)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .yellow, radius: 1)

            VStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    // 背景バー
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.6))
                        .frame(height: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                        )

                    // プログレスバー
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: CGFloat(max(0.0, min(1.0, progress))) * 50, height: 6)
                        .shadow(color: .yellow, radius: energyPulse ? 3 : 1)
                }
                .frame(width: 50)

                Text("\(Int(progress * 10))/10")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .yellow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .yellow, radius: 1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                energyPulse = true
            }
        }
    }
}

struct StatsView: View {
    let gameState: GameState

    var body: some View {
        VStack(spacing: 16) {
            NeonStatItem(
                title: "HEIGHT",
                value: "\(gameState.getColumnHeights().max() ?? 0)",
                color: .red
            )

            NeonStatItem(
                title: "HOLES",
                value: "\(gameState.getHoles())",
                color: .orange
            )
        }
    }
}

struct NeonStatItem: View {
    let title: String
    let value: String
    let color: Color
    @State private var dataPulse = false

    var body: some View {
        VStack(spacing: 4) {
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
                .shadow(color: color, radius: dataPulse ? 2 : 1)
                .scaleEffect(dataPulse ? 1.1 : 1.0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                dataPulse = true
            }
        }
    }
}

struct GameControlsView: View {
    @ObservedObject var gameCore: GameCore

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // 左移動
                GameButton(
                    icon: "arrowshape.left.fill",
                    action: {
                        _ = gameCore.movePiece(dx: -1)
                    }
                )

                Spacer()

                // 回転
                GameButton(
                    icon: "arrow.clockwise",
                    action: {
                        _ = gameCore.rotatePiece()
                    }
                )

                Spacer()

                // 右移動
                GameButton(
                    icon: "arrowshape.right.fill",
                    action: {
                        _ = gameCore.movePiece(dx: 1)
                    }
                )
            }

            HStack(spacing: 20) {
                // ソフトドロップ
                SoftDropButton(gameCore: gameCore)

                Spacer()

                // ハードドロップ
                GameButton(
                    icon: "arrowshape.down.fill",
                    action: {
                        gameCore.hardDrop()
                    },
                    style: .secondary
                )

                Spacer()

                // ポーズ/再開
                GameButton(
                    icon: gameCore.isGameRunning ? "pause.fill" : "play.fill",
                    action: {
                        if gameCore.isGameRunning {
                            gameCore.pauseGame()
                        } else {
                            gameCore.resumeGame()
                        }
                    },
                    style: .secondary
                )
            }
        }
    }
}

enum GameButtonStyle {
    case primary
    case secondary
}

struct GameButton: View {
    let icon: String
    let action: () -> Void
    let style: GameButtonStyle
    @State private var isGlowing = false

    init(icon: String, action: @escaping () -> Void, style: GameButtonStyle = .primary) {
        self.icon = icon
        self.action = action
        self.style = style
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // ベース背景（より鮮やか）
                Circle()
                    .fill(
                        RadialGradient(
                            colors: style == .primary
                                ? [
                                    Color.cyan.opacity(0.9), Color.blue.opacity(0.7),
                                    Color.purple.opacity(0.5), Color.black.opacity(0.8),
                                ]
                                : [
                                    Color.purple.opacity(0.9), Color.pink.opacity(0.7),
                                    Color.gray.opacity(0.6), Color.black.opacity(0.8),
                                ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 60, height: 60)

                // ネオンリング（二重効果）
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: style == .primary
                                ? [.cyan, .blue, .purple, .cyan]
                                : [.purple, .pink, .orange, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 60, height: 60)
                    .shadow(
                        color: style == .primary ? .cyan : .purple,
                        radius: isGlowing ? 12 : 6
                    )
                    .shadow(
                        color: style == .primary ? .blue : .pink,
                        radius: isGlowing ? 8 : 4
                    )

                // アイコン
                Image(systemName: icon)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, style == .primary ? .cyan : .purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: style == .primary ? .cyan : .purple,
                        radius: 2
                    )
            }
        }
        .buttonStyle(NeonButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

struct SoftDropButton: View {
    @ObservedObject var gameCore: GameCore
    @State private var isGlowing = false

    var body: some View {
        Button("↓") {
            // タップ時は1回だけ下に移動
            _ = gameCore.movePiece(dx: 0, dy: 1)
        }
        .font(.title)
        .fontWeight(.black)
        .foregroundStyle(
            LinearGradient(
                colors: [.white, .green],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(width: 60, height: 60)
        .background(
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.green.opacity(0.8), Color.mint.opacity(0.6),
                                Color.black.opacity(0.8),
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 35
                        )
                    )

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.green, .mint, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: .green, radius: isGlowing ? 8 : 4)
            }
        )
        .shadow(color: .green, radius: 2)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    gameCore.startSoftDrop()
                }
                .onEnded { _ in
                    gameCore.stopSoftDrop()
                }
        )
        .buttonStyle(NeonButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

struct NeonButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .brightness(configuration.isPressed ? 0.3 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    GameView(
        gameCore: GameCore(),
        initialPiece: Polyomino(cells: [(0, 0), (0, 1), (1, 0), (1, 1)]),
        pieceProvider: nil
    )
}
