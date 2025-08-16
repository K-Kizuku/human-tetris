//
//  GameCore.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation

// 表情認識のためのimport（FacialExpressionを使用するため）
// Note: 実際のプロジェクトでは適切なモジュール構造に応じて調整が必要

class GameCore: ObservableObject {
    @Published var gameState: GameState
    @Published var isGameRunning: Bool = false
    @Published var dropTimer: Timer?
    @Published var waitingForNextPiece: Bool = false
    @Published var isSoftDropping: Bool = false
    @Published var currentDropSpeedMultiplier: Double = 1.0  // 表情による落下速度倍率

    private let baseDropInterval: TimeInterval = 1.0  // 基本落下間隔
    private let softDropInterval: TimeInterval = 0.05  // 高速落下間隔
    var pieceQueue: PieceQueue?

    init() {
        self.gameState = GameState()
        self.pieceQueue = PieceQueue()
    }

    func setPieceProvider(_ provider: GamePieceProvider) {
        print("GameCore: Setting piece provider")
        pieceQueue?.setProvider(provider)

        // preloadPiecesを非同期で実行してUIフリーズを防ぐ
        DispatchQueue.global(qos: .userInitiated).async {
            self.pieceQueue?.preloadPieces()
        }
        print("GameCore: Piece provider set successfully")
    }

    func startGame() {
        gameState = GameState()
        isGameRunning = true
        startDropTimer()
    }

    func pauseGame() {
        isGameRunning = false
        stopDropTimer()
    }

    func resumeGame() {
        isGameRunning = true
        startDropTimer()
    }

    func endGame() {
        isGameRunning = false
        stopDropTimer()
        gameState.gameOver = true
    }

    private func startDropTimer() {
        // 既存のタイマーを停止
        stopDropTimer()

        // 表情による速度調整を適用
        let adjustedInterval =
            isSoftDropping ? softDropInterval : (baseDropInterval * currentDropSpeedMultiplier)

        print(
            "GameCore: Starting drop timer with interval \(adjustedInterval) (base: \(baseDropInterval), multiplier: \(currentDropSpeedMultiplier), soft drop: \(isSoftDropping))"
        )
        dropTimer = Timer.scheduledTimer(withTimeInterval: adjustedInterval, repeats: true) {
            [weak self] _ in
            self?.dropCurrentPiece()
        }
    }

    private func stopDropTimer() {
        dropTimer?.invalidate()
        dropTimer = nil
    }

    func spawnPiece(_ piece: Polyomino, at column: Int) {
        print(
            "GameCore: spawnPiece called with piece size=\(piece.size), width=\(piece.width), column=\(column)"
        )

        let spawnX = max(0, min(column, GameState.boardWidth - piece.width))
        let spawnY = 0

        print("GameCore: Calculated spawn position (\(spawnX), \(spawnY))")

        if gameState.isValidPosition(piece: piece, at: (x: spawnX, y: spawnY)) {
            print("GameCore: Position is valid, spawning piece")
            gameState.currentPiece = piece
            gameState.currentPosition = (x: spawnX, y: spawnY)
            waitingForNextPiece = false
            print("GameCore: Piece spawned successfully")
        } else {
            print("GameCore: Position is invalid, ending game")
            endGame()
        }
    }

    func requestNextPiece() {
        // ゲームが終了している場合は要求しない
        guard isGameRunning && !gameState.gameOver else {
            print("GameCore: Game not running or over, skipping piece request")
            return
        }

        waitingForNextPiece = true
        print("GameCore: Requesting next piece")

        pieceQueue?.getNextPiece { [weak self] piece in
            DispatchQueue.main.async {
                guard let self = self, self.isGameRunning && !self.gameState.gameOver else {
                    print("GameCore: Game ended while waiting for piece")
                    return
                }

                guard let piece = piece else {
                    print("GameCore: No piece received, ending game")
                    self.endGame()
                    return
                }

                let spawnColumn = Int.random(in: 0...max(0, GameState.boardWidth - piece.width))
                print("GameCore: Spawning next piece at column \(spawnColumn)")
                self.spawnPiece(piece, at: spawnColumn)
            }
        }
    }

    func movePiece(dx: Int, dy: Int = 0) -> Bool {
        guard let piece = gameState.currentPiece else { return false }

        let newPosition = (
            x: gameState.currentPosition.x + dx,
            y: gameState.currentPosition.y + dy
        )

        if gameState.isValidPosition(piece: piece, at: newPosition) {
            gameState.currentPosition = newPosition
            return true
        }

        return false
    }

    func rotatePiece() -> Bool {
        guard let piece = gameState.currentPiece else { return false }

        let rotatedPiece = piece.rotated()

        let kickTable: [(dx: Int, dy: Int)] = [
            (0, 0), (1, 0), (-1, 0), (0, 1), (0, -1),
            (2, 0), (-2, 0), (1, 1), (-1, 1), (0, 2),
        ]

        for kick in kickTable {
            let testPosition = (
                x: gameState.currentPosition.x + kick.dx,
                y: gameState.currentPosition.y + kick.dy
            )

            if gameState.isValidPosition(piece: rotatedPiece, at: testPosition) {
                gameState.currentPiece = rotatedPiece
                gameState.currentPosition = testPosition
                return true
            }
        }

        return false
    }

    func dropCurrentPiece() {
        guard isGameRunning else { return }

        if !movePiece(dx: 0, dy: 1) {
            lockCurrentPiece()
        }
    }

    func hardDrop() {
        guard let piece = gameState.currentPiece else { return }

        var dropDistance = 0
        while gameState.isValidPosition(
            piece: piece,
            at: (
                x: gameState.currentPosition.x,
                y: gameState.currentPosition.y + dropDistance + 1
            ))
        {
            dropDistance += 1
        }

        gameState.currentPosition.y += dropDistance
        lockCurrentPiece()
    }

    func startSoftDrop() {
        guard isGameRunning && !isSoftDropping else { return }
        isSoftDropping = true
        startDropTimer()  // タイマーを高速間隔で再開
    }

    func stopSoftDrop() {
        guard isSoftDropping else { return }
        isSoftDropping = false
        startDropTimer()  // タイマーを通常間隔で再開
    }

    private func lockCurrentPiece() {
        guard let piece = gameState.currentPiece else { return }

        gameState.placePiece(piece: piece, at: gameState.currentPosition)
        gameState.currentPiece = nil

        let linesCleared = gameState.clearLines()
        if linesCleared > 0 {
            updateScore(linesCleared: linesCleared)
        }

        // 次のピースを自動的に要求
        if isGameRunning && !gameState.gameOver {
            requestNextPiece()
        }
    }

    private func updateScore(linesCleared: Int) {
        let lineBonus: [Int] = [0, 1, 3, 5, 7]
        let bonus = lineBonus[min(linesCleared, lineBonus.count - 1)]
        gameState.score += bonus * 100 * gameState.level
    }

    func getGhostPosition() -> (x: Int, y: Int)? {
        guard let piece = gameState.currentPiece else { return nil }

        var ghostY = gameState.currentPosition.y
        while gameState.isValidPosition(
            piece: piece,
            at: (
                x: gameState.currentPosition.x,
                y: ghostY + 1
            ))
        {
            ghostY += 1
        }

        return (x: gameState.currentPosition.x, y: ghostY)
    }

    func calculateScore(iou: Float, stableTime: Float, linesCleared: Int, diversityIndex: Float)
        -> Int
    {
        let alpha: Float = 4.0
        let beta: Float = 10.0
        let gamma: Float = 3.0
        let delta: Float = 5.0

        let lineBonus = [0, 1, 3, 5, 7][min(linesCleared, 4)]
        let iouScore = iou * beta
        let stableScore = min(stableTime, 1.0) * gamma
        let diversityScore = diversityIndex * delta

        return Int(alpha * Float(lineBonus) + iouScore + stableScore + diversityScore)
    }

    func getBoardFeatures() -> (heights: [Int], holes: Int, bumpiness: Int) {
        let heights = gameState.getColumnHeights()
        let holes = gameState.getHoles()

        var bumpiness = 0
        for i in 0..<heights.count - 1 {
            bumpiness += abs(heights[i] - heights[i + 1])
        }

        return (heights: heights, holes: holes, bumpiness: bumpiness)
    }

    var nextPiecePreview: Polyomino? {
        return pieceQueue?.nextPiecePreview
    }

    // MARK: - 表情による落下速度調整

    /// 表情に応じて落下速度を調整する
    /// - Parameter expression: 検出された表情
    /// - Parameter confidence: 表情認識の信頼度（0.0-1.0）
    func updateDropSpeedForExpression(_ expression: FacialExpression, confidence: Float) {
        // 信頼度が低い場合は速度調整を適用しない
        guard confidence >= 0.5 else {
            print("GameCore: Expression confidence too low (\(confidence)), keeping current speed")
            return
        }

        let newMultiplier = expression.dropSpeedMultiplier

        // 速度が変更された場合のみタイマーを再起動
        if abs(currentDropSpeedMultiplier - newMultiplier) > 0.01 {
            print(
                "GameCore: Updating drop speed multiplier from \(currentDropSpeedMultiplier) to \(newMultiplier) for expression: \(expression.rawValue)"
            )

            currentDropSpeedMultiplier = newMultiplier

            // ゲーム実行中の場合はタイマーを再起動して新しい速度を適用
            if isGameRunning && !isSoftDropping {
                startDropTimer()
            }
        }
    }

    /// 現在の落下間隔を取得（デバッグ用）
    var currentDropInterval: TimeInterval {
        return isSoftDropping ? softDropInterval : (baseDropInterval * currentDropSpeedMultiplier)
    }
}
