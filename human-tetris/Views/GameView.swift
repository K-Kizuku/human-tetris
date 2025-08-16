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
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // デバッグ用ヘッダー
            Text("TETRIS GAME")
                .font(.title)
                .foregroundColor(.white)
                .padding(.top)
            
            Text("Initial Piece: \(initialPiece.cells.count) cells")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom)
            // スコア表示
            GameInfoBar(
                score: score,
                lines: lines,
                time: elapsedTime,
                gameOver: gameCore.gameState.gameOver
            )
            .frame(height: 60)
            .background(Color.black.opacity(0.3))
            
            // ゲーム盤面
            HStack(spacing: 20) {
                // 左側：次のピース情報
                VStack(spacing: 20) {
                    NextPieceView(nextPiece: gameCore.nextPiecePreview)
                    
                    LevelIndicator(
                        level: gameCore.gameState.level,
                        progress: Double(lines % 10) / 10.0
                    )
                    
                    Spacer()
                }
                .frame(width: 80)
                
                // 中央：ゲーム盤
                ZStack {
                    GameBoardView(gameCore: gameCore)
                        .scaleEffect(boardScale)
                    
                    // 次ピース待機表示
                    if gameCore.waitingForNextPiece {
                        WaitingForPieceOverlay()
                    }
                }
                .frame(width: 250, height: 500)
                
                // 右側：統計情報
                VStack(spacing: 20) {
                    StatsView(gameState: gameCore.gameState)
                    
                    Spacer()
                }
                .frame(width: 80)
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity)
            
            Spacer()
            
            // 操作ボタン
            GameControlsView(gameCore: gameCore)
                .padding(.horizontal)
                .padding(.bottom, 30)
                .frame(height: 150)
            
            // 緊急用フォールバック表示
            if gameCore.gameState.currentPiece == nil {
                VStack {
                    Text("GAME INITIALIZING...")
                        .font(.title2)
                        .foregroundColor(.yellow)
                    Text("Waiting for pieces...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(Color.red.opacity(0.3))
                .cornerRadius(8)
                .padding()
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.3)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            startGame()
        }
        .onDisappear {
            gameTimer?.invalidate()
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
        print("GameView: Initial piece has \(initialPiece.cells.count) cells: \(initialPiece.cells)")
        
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

struct GameInfoBar: View {
    let score: Int
    let lines: Int
    let time: TimeInterval
    let gameOver: Bool
    
    private var formattedTime: String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        HStack {
            InfoItem(title: "スコア", value: "\(score)")
            Spacer()
            InfoItem(title: "ライン", value: "\(lines)")
            Spacer()
            InfoItem(title: "時間", value: formattedTime)
            
            if gameOver {
                Spacer()
                Text("GAME OVER")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .animation(.bouncy, value: gameOver)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
    }
}

struct InfoItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

struct NextPieceView: View {
    let nextPiece: Polyomino?
    
    var body: some View {
        VStack(spacing: 8) {
            Text("次のピース")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Group {
                        if let piece = nextPiece {
                            NextPiecePreview(piece: piece)
                        } else {
                            Text("?")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                )
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
    
    var body: some View {
        VStack(spacing: 8) {
            Text("レベル \(level)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            
            VStack(spacing: 4) {
                ProgressView(value: max(0.0, min(1.0, progress)))
                    .tint(.yellow)
                    .frame(height: 4)
                
                Text("\(Int(progress * 10))/10")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

struct StatsView: View {
    let gameState: GameState
    
    var body: some View {
        VStack(spacing: 16) {
            StatItem(
                title: "高さ",
                value: "\(gameState.getColumnHeights().max() ?? 0)"
            )
            
            StatItem(
                title: "穴",
                value: "\(gameState.getHoles())"
            )
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
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
    
    init(icon: String, action: @escaping () -> Void, style: GameButtonStyle = .primary) {
        self.icon = icon
        self.action = action
        self.style = style
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    style == .primary ? 
                    Color.blue.opacity(0.8) : 
                    Color.gray.opacity(0.6)
                )
                .cornerRadius(30)
                .shadow(radius: 4)
        }
        .buttonStyle(PressedButtonStyle())
    }
}

struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
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