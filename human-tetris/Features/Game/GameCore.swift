//
//  GameCore.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation
import SwiftUI
import AVFoundation

// 表情認識のためのimport（FacialExpressionを使用するため）
// Note: 実際のプロジェクトでは適切なモジュール構造に応じて調整が必要

class GameCore: ObservableObject {
    @Published var gameState: GameState
    @Published var isGameRunning: Bool = false
    @Published var waitingForNextPiece: Bool = false
    @Published var isSoftDropping: Bool = false
    @Published var currentDropSpeedMultiplier: Double = 1.0  // 表情による落下速度倍率
    @Published var isAnimating: Bool = false  // アニメーション中の状態
    
    // 緊張感演出用
    @Published var tensionLevel: TensionLevel = .calm
    @Published var dangerZoneActive: Bool = false
    @Published var criticalWarning: Bool = false
    @Published var quickActionTrigger: Int = 0

    // タイマー管理の改善
    private var dropTimer: Timer?
    private var animationTimer: Timer?
    private let gameQueue = DispatchQueue(label: "game.core.queue", qos: .userInteractive)
    
    // ゲーム設定の最適化
    private let baseDropInterval: TimeInterval = 0.8  // 基本落下間隔（少し早めに調整）
    private let softDropInterval: TimeInterval = 0.04  // 高速落下間隔（より応答性向上）
    private let animationDuration: TimeInterval = 0.15  // アニメーション時間
    
    var pieceQueue: PieceQueue?
    
    // 状態管理の改善
    private var lastDropTime: CFTimeInterval = 0
    private var pendingOperations: [() -> Void] = []
    private var isProcessingOperation: Bool = false

    init() {
        self.gameState = GameState()
        self.pieceQueue = PieceQueue()
    }
    
    deinit {
        // リソースの適切な解放
        stopAllTimers()
        print("GameCore: Deinitializing, timers stopped")
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
        print("GameCore: Starting game")
        gameState = GameState()
        isGameRunning = true
        isAnimating = false
        waitingForNextPiece = false
        
        // 緊張状態をリセット
        tensionLevel = .calm
        dangerZoneActive = false
        criticalWarning = false
        quickActionTrigger = 0
        
        startDropTimer()
        print("GameCore: Game started successfully")
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

    // MARK: - 改善されたタイマー管理
    
    private func startDropTimer() {
        stopDropTimer()
        
        let adjustedInterval = isSoftDropping 
            ? softDropInterval 
            : (baseDropInterval * currentDropSpeedMultiplier)

        print("GameCore: Starting optimized drop timer - interval: \(adjustedInterval)")
        
        dropTimer = Timer.scheduledTimer(withTimeInterval: adjustedInterval, repeats: true) { [weak self] _ in
            // 落下処理は直接実行（キューイングしない）
            DispatchQueue.main.async {
                self?.dropCurrentPiece()
            }
        }
        
        // タイマーをメインランループに追加して安定性向上
        if let timer = dropTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopDropTimer() {
        dropTimer?.invalidate()
        dropTimer = nil
    }
    
    private func stopAllTimers() {
        stopDropTimer()
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    // MARK: - 操作の非同期処理とキューイング
    
    private func executeGameOperation(_ operation: @escaping () -> Void) {
        // アニメーション中でも落下は継続する（他の操作のみキューイング）
        guard !isProcessingOperation else {
            pendingOperations.append(operation)
            return
        }
        
        isProcessingOperation = true
        operation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in // 60FPS対応
            self?.isProcessingOperation = false
            self?.processPendingOperations()
        }
    }
    
    private func processPendingOperations() {
        guard !pendingOperations.isEmpty && !isProcessingOperation && !isAnimating else { return }
        
        let operation = pendingOperations.removeFirst()
        executeGameOperation(operation)
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
            isAnimating = false  // アニメーション状態をリセット
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
        guard let piece = gameState.currentPiece else { 
            print("GameCore: movePiece - no current piece")
            return false 
        }
        
        // 落下（dy > 0）はアニメーション中でも実行可能
        let isDropOperation = dy > 0 && dx == 0
        guard !isAnimating || isDropOperation else { 
            print("GameCore: movePiece blocked by animation")
            return false 
        }

        let newPosition = (
            x: gameState.currentPosition.x + dx,
            y: gameState.currentPosition.y + dy
        )
        
        print("GameCore: Attempting to move piece from (\(gameState.currentPosition.x), \(gameState.currentPosition.y)) to (\(newPosition.x), \(newPosition.y))")

        if gameState.isValidPosition(piece: piece, at: newPosition) {
            // すべての移動を即座実行（アニメーションなし）
            gameState.currentPosition = newPosition
            
            // 緊張感のある横移動時の効果
            if dx != 0 {
                triggerQuickMoveEffect()
            }
            
            print("GameCore: Move successful")
            return true
        }
        
        print("GameCore: Move failed - invalid position")
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
                // 回転はアニメーションなしで即座実行
                gameState.currentPiece = rotatedPiece
                gameState.currentPosition = testPosition
                triggerTensionEffect()
                return true
            }
        }

        return false
    }

    func dropCurrentPiece() {
        guard isGameRunning && !gameState.gameOver else { 
            print("GameCore: Cannot drop piece - game not running or over")
            return 
        }
        
        guard gameState.currentPiece != nil else {
            print("GameCore: No current piece to drop")
            return
        }
        
        print("GameCore: Attempting to drop piece")
        if !movePiece(dx: 0, dy: 1) {
            print("GameCore: Piece cannot move down, locking")
            lockCurrentPiece()
        } else {
            print("GameCore: Piece dropped successfully")
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
        guard let piece = gameState.currentPiece else { 
            print("GameCore: lockCurrentPiece - no current piece")
            return 
        }
        
        print("GameCore: Locking piece at position (\(gameState.currentPosition.x), \(gameState.currentPosition.y))")

        // ピースを即座に配置
        gameState.placePiece(piece: piece, at: gameState.currentPosition)
        gameState.currentPiece = nil
        
        // ライン消去チェック
        let linesCleared = gameState.clearLines()
        if linesCleared > 0 {
            print("GameCore: Lines cleared: \(linesCleared)")
            updateScore(linesCleared: linesCleared)
            
            // 短時間のアニメーション表示
            isAnimating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.finalizePieceLock()
            }
        } else {
            finalizePieceLock()
        }
        
        // 緊張レベルを更新
        updateTensionLevel()
    }
    
    private func animateLineClear(linesCleared: Int, completion: @escaping () -> Void) {
        print("GameCore: Quick line clear animation for \(linesCleared) lines")
        
        // 短時間のライン消去アニメーション
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            completion()
        }
    }
    
    private func finalizePieceLock() {
        print("GameCore: Finalizing piece lock")
        isAnimating = false
        
        // 緊張レベルを再更新
        updateTensionLevel()
        
        // 次のピースを要求
        if isGameRunning && !gameState.gameOver {
            print("GameCore: Requesting next piece after lock")
            requestNextPiece()
        } else {
            print("GameCore: Game not running or game over, not requesting next piece")
        }
        
        // 保留中の操作を処理
        processPendingOperations()
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
        guard confidence >= 0.4 else {  // 閾値を少し下げて応答性向上
            return
        }

        let newMultiplier = expression.dropSpeedMultiplier

        // 速度変更の閾値を小さくして、より敏感に反応
        if abs(currentDropSpeedMultiplier - newMultiplier) > 0.05 {
            print("GameCore: Smooth speed transition from \(currentDropSpeedMultiplier) to \(newMultiplier)")

            // スムーズな速度変更
            withAnimation(.easeInOut(duration: 0.3)) {
                currentDropSpeedMultiplier = newMultiplier
            }

            // タイマー再起動の頻度を制限
            executeGameOperation { [weak self] in
                guard let self = self,
                      self.isGameRunning && !self.isSoftDropping else { return }
                self.startDropTimer()
            }
        }
    }

    /// 現在の落下間隔を取得（デバッグ用）
    var currentDropInterval: TimeInterval {
        let baseInterval = isSoftDropping ? softDropInterval : (baseDropInterval * currentDropSpeedMultiplier)
        // 緊張レベルに応じた速度調整
        return baseInterval * tensionLevel.speedMultiplier
    }
    
    // MARK: - 緊張感演出システム
    
    private func updateTensionLevel() {
        let heights = gameState.getColumnHeights()
        let maxHeight = heights.max() ?? 0
        let holes = gameState.getHoles()
        
        // 危険度の計算
        let heightDanger = Double(maxHeight) / Double(GameState.boardHeight)
        let holeDanger = min(Double(holes) / 10.0, 1.0)
        let totalDanger = (heightDanger * 0.7) + (holeDanger * 0.3)
        
        let newTensionLevel: TensionLevel
        let newDangerZone: Bool
        let newCriticalWarning: Bool
        
        switch totalDanger {
        case 0.0..<0.3:
            newTensionLevel = .calm
            newDangerZone = false
            newCriticalWarning = false
        case 0.3..<0.6:
            newTensionLevel = .tense
            newDangerZone = false
            newCriticalWarning = false
        case 0.6..<0.8:
            newTensionLevel = .danger
            newDangerZone = true
            newCriticalWarning = false
        default:
            newTensionLevel = .critical
            newDangerZone = true
            newCriticalWarning = true
        }
        
        // 状態が変化した場合のみ更新
        if tensionLevel != newTensionLevel {
            print("GameCore: Tension level changed from \(tensionLevel) to \(newTensionLevel)")
            tensionLevel = newTensionLevel
            
            // タイマーの再設定
            if isGameRunning {
                startDropTimer()
            }
        }
        
        dangerZoneActive = newDangerZone
        criticalWarning = newCriticalWarning
    }
    
    private func triggerTensionEffect() {
        // 回転時のクイックアクションエフェクト
        quickActionTrigger += 1
    }
    
    private func triggerQuickMoveEffect() {
        // 横移動時のクイックアクションエフェクト
        quickActionTrigger += 1
    }
}

// MARK: - 緊張レベル定義

enum TensionLevel: String, CaseIterable {
    case calm = "平安"
    case tense = "緊張"
    case danger = "危険"
    case critical = "緊急"
    
    var speedMultiplier: Double {
        switch self {
        case .calm: return 1.0
        case .tense: return 0.9
        case .danger: return 0.8
        case .critical: return 0.7
        }
    }
    
    var color: SwiftUI.Color {
        switch self {
        case .calm: return .green
        case .tense: return .yellow
        case .danger: return .orange
        case .critical: return .red
        }
    }
    
    var emoji: String {
        switch self {
        case .calm: return "😌"
        case .tense: return "😐"
        case .danger: return "😨"
        case .critical: return "😱"
        }
    }
}

// MARK: - Audio System (Temporary in GameCore)
enum AudioFile: String {
    case gameBGM = "bgm2"
    case menuBGM = "dodo~n"  
    case scoreSound = "charge"
    case buttonSound = "do~un"
}

class AudioManager: ObservableObject {
    static let shared = AudioManager()
    
    @Published var isBGMEnabled: Bool = true
    @Published var isSFXEnabled: Bool = true
    
    private var bgmPlayer: AVAudioPlayer?
    private var currentBGM: AudioFile?
    private var sfxPlayers: [AVAudioPlayer] = []  // SFXプレイヤーの参照を保持
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            // ゲーム用音声再生に適した設定
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("AudioManager: Audio session configured successfully for ambient playback")
        } catch {
            print("AudioManager: Failed to setup audio session: \(error)")
        }
    }
    
    func playBGM(_ audioFile: AudioFile) {
        guard isBGMEnabled else { 
            print("AudioManager: BGM disabled")
            return 
        }
        if currentBGM == audioFile && bgmPlayer?.isPlaying == true { 
            print("AudioManager: BGM \(audioFile.rawValue) already playing")
            return 
        }
        
        stopBGM()
        guard let dataAsset = NSDataAsset(name: audioFile.rawValue) else { 
            print("AudioManager: Could not find \(audioFile.rawValue) in Assets.xcassets")
            return 
        }
        
        do {
            // Audio Sessionを再設定
            try AVAudioSession.sharedInstance().setActive(true)
            
            bgmPlayer = try AVAudioPlayer(data: dataAsset.data)
            bgmPlayer?.numberOfLoops = -1
            bgmPlayer?.volume = 0.7
            bgmPlayer?.prepareToPlay()
            
            let success = bgmPlayer?.play() ?? false
            if success {
                currentBGM = audioFile
                print("AudioManager: Successfully playing BGM: \(audioFile.rawValue)")
            } else {
                print("AudioManager: Failed to start BGM playback")
            }
        } catch {
            print("AudioManager: BGM play failed: \(error)")
        }
    }
    
    func stopBGM() {
        if bgmPlayer?.isPlaying == true {
            bgmPlayer?.stop()
            print("AudioManager: Stopped BGM")
        }
        bgmPlayer = nil
        currentBGM = nil
    }
    
    func playSFX(_ audioFile: AudioFile) {
        guard isSFXEnabled else { 
            print("AudioManager: SFX disabled")
            return 
        }
        guard let dataAsset = NSDataAsset(name: audioFile.rawValue) else { 
            print("AudioManager: Could not find SFX \(audioFile.rawValue) in Assets.xcassets")
            return 
        }
        
        do {
            let player = try AVAudioPlayer(data: dataAsset.data)
            player.volume = 0.8
            player.prepareToPlay()
            
            // SFXプレイヤーの参照を保持
            sfxPlayers.append(player)
            
            let success = player.play()
            if success {
                print("AudioManager: Successfully playing SFX: \(audioFile.rawValue)")
            } else {
                print("AudioManager: Failed to start SFX playback")
            }
            
            // 再生完了後にプレイヤーの参照を削除
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if let index = self.sfxPlayers.firstIndex(of: player) {
                    self.sfxPlayers.remove(at: index)
                }
            }
        } catch {
            print("AudioManager: SFX play failed: \(error)")
        }
    }
    
    func playGameBGM() { playBGM(.gameBGM) }
    func playMenuBGM() { playSFX(.menuBGM) }
    func playScoreSound() { playSFX(.scoreSound) }
    func playButtonSound() { playSFX(.buttonSound) }
    
    // デバッグ用：音声ファイルの存在確認
    func testAudioFiles() {
        let audioFiles: [AudioFile] = [.gameBGM, .menuBGM, .scoreSound, .buttonSound]
        for file in audioFiles {
            if let dataAsset = NSDataAsset(name: file.rawValue) {
                print("AudioManager: ✅ Found \(file.rawValue) - Size: \(dataAsset.data.count) bytes")
            } else {
                print("AudioManager: ❌ Missing \(file.rawValue)")
            }
        }
    }
}


