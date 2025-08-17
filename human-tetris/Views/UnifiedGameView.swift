//
//  UnifiedGameView.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import AVFoundation
import SwiftUI
import Vision

struct UnifiedGameView: View, GamePieceProvider {
    // ARKit一本化: MultiCameraManagerは不要
    @StateObject private var facialExpressionManager = FacialExpressionManager()
    @StateObject private var visionProcessor = VisionProcessor()
    @StateObject private var quantizationProcessor = QuantizationProcessor()
    @StateObject private var shapeExtractor = ShapeExtractor()
    @StateObject private var gameCore = GameCore()
    @StateObject private var countdownManager = CountdownManager()
    @StateObject private var shapeHistoryManager = ShapeHistoryManager()

    @State private var roiFrame = CGRect(x: 100, y: 200, width: 200, height: 150)
    @State private var currentIoU: Float = 0.0
    @State private var captureState = CaptureState()
    @State private var showFlashEffect = false
    @State private var isGameActive = false
    @State private var showSuccessHighlight = false
    @State private var showFailureHighlight = false
    @State private var showResultScreen = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ネオン宇宙背景
                NeonColors.mainBackgroundGradient
                    .ignoresSafeArea()
                
                // 軽量パーティクル背景（ゲーム中は控えめ）
                NeonGameParticleBackground()

                VStack(spacing: 4) {
                    // Top section - ネオンカメラセクション (高さ比率調整)
                    HStack {
                        Spacer()
                        cameraSection(geometry: geometry)
                            .frame(height: min(geometry.size.height * 0.25, 200))
                        Spacer()
                    }

                    // Bottom section - ネオンゲームボード (高さ比率調整)
                    gameBoardSection(geometry: geometry)
                        .frame(height: geometry.size.height * 0.75)
                }
                .padding(.horizontal, 6)

                // ネオンフラッシュエフェクト
                if showFlashEffect {
                    Rectangle()
                        .fill(
                            RadialGradient(
                                colors: [NeonColors.neonCyan.opacity(0.8), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 400
                            )
                        )
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.2), value: showFlashEffect)
                }

                // ネオン成功/失敗ハイライト
                if showSuccessHighlight {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(NeonColors.neonGreen, lineWidth: 3)
                        .frame(
                            width: geometry.size.width * 0.8, height: geometry.size.height * 0.22
                        )
                        .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.125)
                        .neonGlow(color: NeonColors.neonGreen, radius: 20, intensity: 1.2)
                        .animation(.bouncy, value: showSuccessHighlight)
                }

                if showFailureHighlight {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(NeonColors.neonOrange, lineWidth: 3)
                        .frame(
                            width: geometry.size.width * 0.8, height: geometry.size.height * 0.22
                        )
                        .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.125)
                        .neonGlow(color: NeonColors.neonOrange, radius: 20, intensity: 1.2)
                        .animation(.bouncy, value: showFailureHighlight)
                }
                
                // フルスクリーン result.png 表示
                if showResultScreen {
                    NeonResultFullScreenView {
                        showResultScreen = false
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1000)
                }
            }
        }
        .onAppear {
            setupComponents()
        }
        .onDisappear {
            cleanupComponents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cameraFlashTriggered)) { _ in
            triggerFlashEffect()
        }
    }

    // MARK: - Camera Section

    private func calculateCameraWidth(for geometry: GeometryProxy) -> CGFloat {
        let cameraHeight = geometry.size.height * 0.22  // 更新された高さ比率
        let deviceAspectRatio = geometry.size.width / geometry.size.height

        // デバイスのアスペクト比を維持してカメラ幅を計算
        let cameraWidth = cameraHeight * deviceAspectRatio

        // 最大幅を画面幅の90%に制限
        let maxWidth = geometry.size.width * 0.9

        return min(cameraWidth, maxWidth)
    }

    @ViewBuilder
    private func cameraSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 4) {
            // Camera and overlays
            ZStack {
                // ARKit unified camera preview - 実際の背面カメラ映像を表示
                if facialExpressionManager.isTracking {
                    ARCameraPreview(pixelBuffer: .constant(facialExpressionManager.currentBackCameraFrame))
                        .aspectRatio(geometry.size.width / geometry.size.height, contentMode: .fill)
                        .clipped()
                        .onAppear {
                            updateROIFrame(for: geometry.size)
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            updateROIFrame(for: newSize)
                        }
                } else {
                    // ARKit unavailable fallback
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(geometry.size.width / geometry.size.height, contentMode: .fill)
                        .clipped()
                        .overlay(
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("ARKit未対応")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                Text("ARKitが利用できません")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                        )
                        .onAppear {
                            updateROIFrame(for: geometry.size)
                        }
                }

                // 4x3 Grid overlay - カメラ全体のサイズに合わせる
                Grid4x3Overlay(
                    cameraWidth: calculateCameraWidth(for: geometry),
                    cameraHeight: geometry.size.height * 0.25
                )

                // Occupancy heatmap - カメラ全体のサイズに合わせる
                OccupancyHeatmap(
                    grid: captureState.grid,
                    cameraWidth: calculateCameraWidth(for: geometry),
                    cameraHeight: geometry.size.height * 0.25
                )

                // Semi-transparent cell overlay for current piece preview
                if let currentPiece = gameCore.gameState.currentPiece {
                    cellOverlay(for: currentPiece, geometry: geometry)
                }

                // Countdown display
                if countdownManager.isCountingDown {
                    countdownOverlay
                }
            }
            .frame(height: geometry.size.height * 0.25)
            .frame(width: calculateCameraWidth(for: geometry))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(NeonColors.neonCyan, lineWidth: 2)
            )
            .neonGlow(color: NeonColors.neonCyan, radius: 12, intensity: 0.8)

            // 表情認識オーバーレイを左上に配置
            HStack {
                FacialExpressionOverlay(
                    expression: facialExpressionManager.currentExpression,
                    confidence: facialExpressionManager.confidence,
                    isFaceDetected: facialExpressionManager.isFaceDetected,
                    isTracking: facialExpressionManager.isTracking,
                    currentDropSpeedMultiplier: gameCore.currentDropSpeedMultiplier,
                    isARKitSupported: facialExpressionManager.isARKitSupported
                )
                .frame(maxWidth: 150)
                .neonGlow(color: NeonColors.neonCyan, radius: 8, intensity: 0.6)
                
                Spacer()
            }
            .padding(.horizontal, 6)
            
            // ネオンコンパクトコントロールセクション
            HStack(spacing: 8) {
                // IoU indicator - ネオンスタイル
                HStack(spacing: 3) {
                    Text("IoU:")
                        .foregroundColor(NeonColors.neonCyan)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .neonGlow(color: NeonColors.neonCyan, radius: 3, intensity: 0.8)
                    
                    ProgressView(value: max(0.0, min(1.0, Double(currentIoU))), total: 1.0)
                        .tint(NeonColors.neonGreen)
                        .frame(width: 35, height: 3)
                        .neonGlow(color: NeonColors.neonGreen, radius: 4, intensity: 0.9)
                    
                    Text(String(format: "%.2f", currentIoU))
                        .foregroundColor(NeonColors.neonCyan)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .neonGlow(color: NeonColors.neonCyan, radius: 3, intensity: 0.8)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NeonColors.spaceBlack.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(NeonColors.neonCyan.opacity(0.3), lineWidth: 1)
                        )
                )

                Spacer()

                // Game start/next piece button - ネオンスタイル
                if !isGameActive {
                    Button("開始") {
                        startGame()
                    }
                    .buttonStyle(NeonCompactButtonStyle())
                } else if !countdownManager.isCountingDown {
                    Button("次") {
                        requestNextPiece()
                    }
                    .buttonStyle(NeonCompactButtonStyle())
                }

                Spacer()

                // Stability indicator - ネオンスタイル
                HStack(spacing: 3) {
                    Text("安定:")
                        .foregroundColor(NeonColors.neonPurple)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .neonGlow(color: NeonColors.neonPurple, radius: 3, intensity: 0.8)
                    
                    ProgressView(
                        value: max(0.0, min(1.0, Double(captureState.stableMs) / 1000.0)),
                        total: 1.0
                    )
                    .tint(captureState.isStable ? NeonColors.neonGreen : NeonColors.neonOrange)
                    .frame(width: 35, height: 3)
                    .neonGlow(
                        color: captureState.isStable ? NeonColors.neonGreen : NeonColors.neonOrange, 
                        radius: 4, 
                        intensity: 0.9
                    )
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NeonColors.spaceBlack.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(NeonColors.neonPurple.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 8)
            .frame(height: 32)  // 少し高さを調整

            #if targetEnvironment(simulator)
                if !facialExpressionManager.isTracking {
                    Button("テスト") {
                        generateTestPiece()
                    }
                    .buttonStyle(CompactButtonStyle())
                }
            #endif
        }
    }

    @ViewBuilder
    private func cellOverlay(for piece: Polyomino, geometry: GeometryProxy) -> some View {
        let cameraWidth = calculateCameraWidth(for: geometry)
        let cameraHeight = geometry.size.height * 0.22
        let cellWidth = cameraWidth / 3
        let cellHeight = cameraHeight / 4

        ZStack {
            ForEach(Array(piece.cells.enumerated()), id: \.offset) { index, cell in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [NeonColors.neonCyan.opacity(0.6), NeonColors.deepPurple.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(NeonColors.neonCyan, lineWidth: 1)
                    )
                    .frame(width: cellWidth * 0.9, height: cellHeight * 0.9)
                    .position(
                        x: (CGFloat(cell.x) + 0.5) * cellWidth,
                        y: (CGFloat(cell.y) + 0.5) * cellHeight
                    )
                    .neonGlow(color: NeonColors.neonCyan, radius: 3, intensity: 0.8)
            }
        }
    }

    @ViewBuilder
    private var countdownOverlay: some View {
        ZStack {
            // ネオンカウントダウン背景
            Circle()
                .fill(NeonColors.spaceBlack.opacity(0.9))
                .frame(width: 90, height: 90)
                .overlay(
                    Circle()
                        .stroke(NeonColors.neonPink, lineWidth: 2)
                )
                .neonGlow(color: NeonColors.neonPink, radius: 15, intensity: 1.0)

            VStack(spacing: 4) {
                if countdownManager.currentCount > 0 {
                    Text("\(countdownManager.currentCount)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .neonGlow(color: NeonColors.neonCyan, radius: 8, intensity: 1.2)
                } else {
                    Text("📸")
                        .font(.system(size: 40))
                        .neonGlow(color: NeonColors.neonYellow, radius: 8, intensity: 1.0)
                }

                // ネオンプログレスリング
                Circle()
                    .trim(from: 0.0, to: CGFloat(countdownManager.progress))
                    .stroke(
                        LinearGradient(
                            colors: [NeonColors.neonGreen, NeonColors.neonCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 5
                    )
                    .frame(width: 65, height: 65)
                    .rotationEffect(.degrees(-90))
                    .neonGlow(color: NeonColors.neonGreen, radius: 6, intensity: 0.8)
            }
        }
    }

    // MARK: - Game Board Section

    @ViewBuilder
    private func gameBoardSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 4) {
            // ネオンスコア表示セクション (コンパクト化)
            HStack(spacing: 8) {
                // 左側スコア情報
                VStack(alignment: .leading, spacing: 2) {
                    Text("スコア: \(gameCore.gameState.score)")
                        .foregroundColor(NeonColors.neonYellow)
                        .font(.caption)
                        .fontWeight(.bold)
                        .neonGlow(color: NeonColors.neonYellow, radius: 4, intensity: 0.9)
                    
                    Text("ライン: \(gameCore.gameState.linesCleared)")
                        .foregroundColor(NeonColors.neonCyan)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .neonGlow(color: NeonColors.neonCyan, radius: 3, intensity: 0.7)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NeonColors.spaceBlack.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(NeonColors.neonYellow.opacity(0.3), lineWidth: 1)
                        )
                )

                Spacer()

                // 中央レベル・多様性情報
                VStack(alignment: .center, spacing: 2) {
                    Text("レベル: \(gameCore.gameState.level)")
                        .foregroundColor(NeonColors.neonGreen)
                        .font(.caption)
                        .fontWeight(.bold)
                        .neonGlow(color: NeonColors.neonGreen, radius: 4, intensity: 0.9)
                    
                    Text("多様性: \(String(format: "%.1f", shapeHistoryManager.diversityScore))")
                        .foregroundColor(NeonColors.neonPurple)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .neonGlow(color: NeonColors.neonPurple, radius: 3, intensity: 0.7)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(NeonColors.spaceBlack.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(NeonColors.neonGreen.opacity(0.3), lineWidth: 1)
                        )
                )

                Spacer()

                // 右側コントロールボタン
                VStack(alignment: .trailing, spacing: 3) {
                    Button(isGameActive ? "一時停止" : "再開") {
                        toggleGamePause()
                    }
                    .buttonStyle(NeonMicroButtonStyle())

                    Button("戻る") {
                        dismiss()
                    }
                    .buttonStyle(NeonMicroButtonStyle())
                    
                    Button("GameOver") {
                        showResultScreen = true
                    }
                    .buttonStyle(NeonMicroButtonStyle(color: NeonColors.neonOrange))
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 40)

            // Game board - サイズ調整で重複防止
            GameBoardView(
                gameCore: gameCore,
                targetSize: CGSize(
                    width: geometry.size.width * 0.82, 
                    height: min(geometry.size.height * 0.40, 280)
                )
            )
            .frame(maxHeight: min(geometry.size.height * 0.40, 280))

            // 改良されたネオンゲームコントロール - コンパクトレイアウト
            VStack(spacing: 8) {
                // 背景カード
                VStack(spacing: 6) {
                    // 上段：回転ボタン
                    HStack {
                        Spacer()
                        Button("🔄") {
                            _ = gameCore.rotatePiece()
                        }
                        .buttonStyle(NeonCompactRotateButtonStyle())
                        Spacer()
                    }
                    
                    // 中段：左右移動 + ハードドロップ
                    HStack(spacing: geometry.size.width * 0.15) {
                        // 左移動
                        Button("◀") {
                            _ = gameCore.movePiece(dx: -1)
                        }
                        .buttonStyle(NeonCompactMoveButtonStyle(color: NeonColors.neonBlue))
                        
                        // ハードドロップ
                        Button("⚡") {
                            gameCore.hardDrop()
                        }
                        .buttonStyle(NeonCompactHardDropButtonStyle())
                        
                        // 右移動
                        Button("▶") {
                            _ = gameCore.movePiece(dx: 1)
                        }
                        .buttonStyle(NeonCompactMoveButtonStyle(color: NeonColors.neonBlue))
                    }
                    
                    // 下段：ソフトドロップ
                    Button("⬇") {
                        _ = gameCore.movePiece(dx: 0, dy: 1)
                    }
                    .buttonStyle(NeonCompactSoftDropButtonStyle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                gameCore.startSoftDrop()
                            }
                            .onEnded { _ in
                                gameCore.stopSoftDrop()
                            }
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            RadialGradient(
                                colors: [NeonColors.deepSpace.opacity(0.4), NeonColors.spaceBlack.opacity(0.9)],
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(NeonColors.neonCyan.opacity(0.4), lineWidth: 1)
                        )
                )
                .neonGlow(color: NeonColors.neonCyan, radius: 6, intensity: 0.3)
            }
            .frame(height: min(geometry.size.height * 0.25, 100))
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Setup and Lifecycle

    private func setupComponents() {
        print("UnifiedGameView: Setting up components with unified ARKit architecture")

        // ARKit一本化: MultiCameraManagerは使用せず、ARSessionから全てのカメラフレームを取得
        facialExpressionManager.delegate = self

        // Setup vision processor
        visionProcessor.delegate = self

        // Setup countdown manager
        countdownManager.delegate = self

        // Setup game core
        gameCore.setPieceProvider(self)

        // ARKitセッションを開始（両方のカメラを管理）
        facialExpressionManager.startTracking()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateROIFrame()
        }
    }

    private func cleanupComponents() {
        print("UnifiedGameView: Cleaning up unified ARKit components")
        facialExpressionManager.stopTracking()
        countdownManager.stopCountdown()
    }

    private func updateROIFrame() {
        // ARKit一本化: プレビューレイヤーではなく画面サイズベースでROI計算
        updateROIFrame(for: UIScreen.main.bounds.size)
    }

    private func updateROIFrame(for bounds: CGSize) {
        // カメラセクションが上部22%を使用、デバイスのアスペクト比を維持
        let cameraHeight = bounds.height * 0.22
        let deviceAspectRatio = bounds.width / bounds.height
        let cameraWidth = min(cameraHeight * deviceAspectRatio, bounds.width * 0.9)

        // ROIフレームをカメラ全体のサイズに設定（量子化は全体で行う）
        let cameraStartX = (bounds.width - cameraWidth) / 2
        roiFrame = CGRect(
            x: cameraStartX,
            y: 0,  // カメラセクション内での相対位置
            width: cameraWidth,
            height: cameraHeight
        )

        print("UnifiedGameView: ROI frame set to full camera size \(roiFrame)")

        // VisionProcessorにカメラ全体のサイズを通知
        visionProcessor.updateROI(
            frame: roiFrame, previewBounds: CGRect(origin: .zero, size: bounds))
    }

    // MARK: - Game Logic

    private func startGame() {
        print("UnifiedGameView: Starting game")
        isGameActive = true
        gameCore.startGame()
        shapeHistoryManager.clearHistory()
        requestNextPiece()
    }

    private func requestNextPiece() {
        print("UnifiedGameView: Requesting next piece")
        countdownManager.startCountdown()
    }

    private func toggleGamePause() {
        if isGameActive {
            gameCore.pauseGame()
            countdownManager.pauseCountdown()
        } else {
            gameCore.resumeGame()
            countdownManager.resumeCountdown()
        }
        isGameActive.toggle()
    }

    private func triggerFlashEffect() {
        showFlashEffect = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showFlashEffect = false
        }
    }

    private func showSuccessEffect() {
        showSuccessHighlight = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showSuccessHighlight = false
        }
    }

    private func showFailureEffect() {
        showFailureHighlight = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showFailureHighlight = false
        }
    }

    #if targetEnvironment(simulator)
        private func generateTestPiece() {
            let testPiece = Polyomino(cells: [
                (x: 0, y: 0),
                (x: 0, y: 1),
                (x: 0, y: 2),
                (x: 1, y: 2),
            ])

            providePieceToGame(testPiece)
        }
    #endif

    private func providePieceToGame(_ piece: Polyomino) {
        shapeHistoryManager.addShape(piece)
        let spawnColumn = piece.cells.isEmpty ? 5 : piece.cells.map { $0.x }.min() ?? 5
        gameCore.spawnPiece(piece, at: spawnColumn)
        showSuccessEffect()
    }

    // ARKit一本化により、setupCameraメソッドは不要 - setupComponents()で統合処理
}

// MARK: - GamePieceProvider

extension UnifiedGameView {
    func requestNextPiece(completion: @escaping (Polyomino?) -> Void) {
        print("UnifiedGameView: GamePieceProvider requestNextPiece called")

        DispatchQueue.global(qos: .userInitiated).async {
            if self.captureState.isStable && self.currentIoU >= 0.6,
                let extractedPiece = self.shapeExtractor.extractBestShape(
                    from: self.captureState.grid)
            {

                let validation = self.shapeHistoryManager.validatePiece(extractedPiece)
                if validation.isValid {
                    DispatchQueue.main.async {
                        completion(extractedPiece)
                    }
                    return
                }
            }

            // Fallback after timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                let fallbackPiece = self.shapeHistoryManager.generateFallbackPiece()
                completion(fallbackPiece)
            }
        }
    }

    func isAvailable() -> Bool {
        return visionProcessor.detectionEnabled && facialExpressionManager.isTracking
    }

    func beginCountdown() {
        print("UnifiedGameView: Beginning countdown")
        countdownManager.startCountdown()
    }

    func cancelCountdown() {
        print("UnifiedGameView: Cancelling countdown")
        countdownManager.stopCountdown()
    }

    func captureAtZero() -> Polyomino? {
        print("UnifiedGameView: Capturing at zero")
        let currentGrid = captureState.grid

        if let extractedPiece = shapeExtractor.extractBestShape(from: currentGrid) {
            let validation = shapeHistoryManager.validatePiece(extractedPiece)
            if validation.isValid {
                print(
                    "UnifiedGameView: Successfully captured piece at zero: \(extractedPiece.cells.count) cells"
                )
                return extractedPiece
            } else {
                print(
                    "UnifiedGameView: Validation failed: \(validation.errorMessage ?? "Unknown error")"
                )
            }
        }

        return nil
    }

    func fallbackTetromino() -> Polyomino {
        print("UnifiedGameView: Generating fallback tetromino")
        return shapeHistoryManager.generateFallbackPiece()
    }
}

// MARK: - CountdownManagerDelegate

extension UnifiedGameView: CountdownManagerDelegate {
    func countdownManager(_ manager: CountdownManager, didUpdateCount count: Int) {
        print("UnifiedGameView: Countdown updated to \(count)")
    }

    func countdownManagerDidReachZero(_ manager: CountdownManager) {
        print("UnifiedGameView: Countdown reached zero")

        if let piece = captureAtZero() {
            providePieceToGame(piece)
        } else {
            let fallbackPiece = fallbackTetromino()
            providePieceToGame(fallbackPiece)
            showFailureEffect()
        }
    }

    func countdownManager(_ manager: CountdownManager, didEncounterError error: Error) {
        print("UnifiedGameView: Countdown error: \(error)")
    }
}

// MultiCameraManagerDelegateは削除 - ARKit一本化により不要

// MARK: - FacialExpressionManagerDelegate

extension UnifiedGameView: FacialExpressionManagerDelegate {
    func facialExpressionManager(
        _ manager: FacialExpressionManager, didDetectExpression result: FacialExpressionResult
    ) {
        // 表情認識の結果を受け取る
        print(
            "UnifiedGameView: Detected expression: \(result.expression.rawValue) with confidence: \(result.confidence), speed multiplier: \(result.expression.dropSpeedMultiplier)"
        )

        // GameCoreに表情による落下速度調整を適用
        gameCore.updateDropSpeedForExpression(result.expression, confidence: result.confidence)
    }

    func facialExpressionManager(_ manager: FacialExpressionManager, didEncounterError error: Error)
    {
        print("UnifiedGameView: Facial expression error: \(error)")
    }
    
    func facialExpressionManager(
        _ manager: FacialExpressionManager, didOutputBackCameraFrame pixelBuffer: CVPixelBuffer
    ) {
        // 統合ARSessionから背面カメラフレームを受け取ってVision処理に送る
        visionProcessor.processFrame(pixelBuffer)
    }
}

// MARK: - VisionProcessorDelegate

extension UnifiedGameView: VisionProcessorDelegate {
    func visionProcessor(
        _ processor: VisionProcessor, didDetectPersonMask mask: CVPixelBuffer, in roi: CGRect
    ) {
        let grid = quantizationProcessor.quantize(
            mask: mask,
            roi: roi,
            threshold: quantizationProcessor.getAdaptiveThreshold()
        )

        DispatchQueue.main.async {
            self.captureState.grid = grid

            if let candidate = self.shapeExtractor.extractBestShape(from: grid) {
                self.currentIoU = Float(candidate.cells.count) / 4.0  // Simplified IoU calculation
                self.captureState.iou = self.currentIoU
                self.captureState.stableMs = Int(self.quantizationProcessor.stableTime * 1000)
            }
        }
    }

    func visionProcessor(
        _ processor: VisionProcessor, didDetectPose pose: VNHumanBodyPoseObservation
    ) {
        // Additional pose validation if needed
    }

    func visionProcessor(_ processor: VisionProcessor, didEncounterError error: Error) {
        print("UnifiedGameView: Vision processing error: \(error)")
    }
}

// MARK: - ネオンボタンスタイル

/// ネオンコンパクトボタンスタイル
struct NeonCompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(NeonColors.buttonGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(NeonColors.neonPink, lineWidth: 1)
                    )
            )
            .neonGlow(
                color: NeonColors.neonPink,
                radius: configuration.isPressed ? 4 : 8,
                intensity: configuration.isPressed ? 0.6 : 1.0
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// ネオンマイクロボタンスタイル
struct NeonMicroButtonStyle: ButtonStyle {
    let color: Color
    
    init(color: Color = NeonColors.neonPurple) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.7), color.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(color.opacity(0.8), lineWidth: 0.5)
                    )
            )
            .neonGlow(
                color: color,
                radius: configuration.isPressed ? 2 : 4,
                intensity: configuration.isPressed ? 0.4 : 0.7
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// コンパクトネオン回転ボタンスタイル
struct NeonCompactRotateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 50, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [NeonColors.neonPurple.opacity(0.9), NeonColors.deepPurple.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(NeonColors.neonPurple, lineWidth: 1.5)
                    )
            )
            .neonGlow(
                color: NeonColors.neonPurple,
                radius: configuration.isPressed ? 6 : 10,
                intensity: configuration.isPressed ? 0.8 : 1.0
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .brightness(configuration.isPressed ? 0.2 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// コンパクトネオン移動ボタンスタイル
struct NeonCompactMoveButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 45, height: 35)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 1.5)
                    )
            )
            .neonGlow(
                color: color,
                radius: configuration.isPressed ? 4 : 8,
                intensity: configuration.isPressed ? 0.7 : 0.9
            )
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// コンパクトネオンハードドロップボタンスタイル
struct NeonCompactHardDropButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .fontWeight(.black)
            .foregroundColor(.white)
            .frame(width: 45, height: 35)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [NeonColors.neonOrange.opacity(0.9), NeonColors.neonOrange.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(NeonColors.neonOrange, lineWidth: 1.5)
                    )
            )
            .neonGlow(
                color: NeonColors.neonOrange,
                radius: configuration.isPressed ? 6 : 10,
                intensity: configuration.isPressed ? 0.8 : 1.0
            )
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .brightness(configuration.isPressed ? 0.2 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// コンパクトネオンソフトドロップボタンスタイル
struct NeonCompactSoftDropButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 120, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [NeonColors.neonGreen.opacity(0.8), NeonColors.neonGreen.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(NeonColors.neonGreen, lineWidth: 1.5)
                    )
            )
            .neonGlow(
                color: NeonColors.neonGreen,
                radius: configuration.isPressed ? 4 : 8,
                intensity: configuration.isPressed ? 0.7 : 0.9
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// レガシー - ネオンゲームコントロールボタンスタイル
struct NeonGameControlButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 50, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color, lineWidth: 1.5)
                    )
            )
            .neonGlow(
                color: color,
                radius: configuration.isPressed ? 6 : 12,
                intensity: configuration.isPressed ? 0.8 : 1.0
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .brightness(configuration.isPressed ? 0.1 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Legacy Button Styles for Compatibility

struct CompactControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .foregroundColor(.white)
            .frame(width: 45, height: 35)
            .background(
                configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue.opacity(0.6)
            )
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: .blue, radius: configuration.isPressed ? 8 : 5) // ネオングロー
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CompactSoftDropButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .foregroundColor(.white)
            .frame(width: 45, height: 35)
            .background(
                configuration.isPressed ? Color.green.opacity(0.8) : Color.green.opacity(0.6)
            )
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: .green, radius: configuration.isPressed ? 8 : 5) // ネオングロー
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CompactHardDropButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .foregroundColor(.white)
            .frame(width: 45, height: 35)
            .background(
                configuration.isPressed ? Color.red.opacity(0.8) : Color.red.opacity(0.6)
            )
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: .red, radius: configuration.isPressed ? 8 : 5) // ネオングロー
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Legacy button styles for compatibility
struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(.white)
            .frame(width: 50, height: 40)
            .background(
                configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue.opacity(0.6)
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SoftDropButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(.white)
            .frame(width: 50, height: 40)
            .background(
                configuration.isPressed ? Color.green.opacity(0.8) : Color.green.opacity(0.6)
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct HardDropButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(.white)
            .frame(width: 50, height: 40)
            .background(
                configuration.isPressed ? Color.red.opacity(0.8) : Color.red.opacity(0.6)
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Compact Button Style

struct CompactButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue.opacity(0.6)
            )
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: .blue, radius: configuration.isPressed ? 6 : 3) // ネオングロー
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// ゲーム用軽量パーティクル背景
struct NeonGameParticleBackground: View {
    @State private var particles: [NeonGameParticle] = []
    @State private var animationTimer: Timer?
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .blur(radius: particle.blur)
                    .neonGlow(color: particle.color, radius: particle.size * 0.3, intensity: 0.4)
            }
        }
        .onAppear {
            generateParticles()
            startAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
    }
    
    private func generateParticles() {
        particles = (0..<8).map { _ in  // ゲーム中は少なめに
            NeonGameParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                color: [NeonColors.neonPink, NeonColors.neonCyan, NeonColors.neonPurple].randomElement()!,
                size: CGFloat.random(in: 1...4),  // 小さめ
                opacity: Double.random(in: 0.2...0.5),  // 控えめ
                blur: CGFloat.random(in: 1...2)
            )
        }
    }
    
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in  // 低頻度
            withAnimation(.linear(duration: 0.2)) {
                for i in particles.indices {
                    particles[i].position.x += CGFloat.random(in: -0.5...0.5)  // ゆっくり
                    particles[i].position.y += CGFloat.random(in: -0.5...0.5)
                    particles[i].opacity = Double.random(in: 0.1...0.6)
                    
                    // 画面外に出たら反対側から再登場
                    if particles[i].position.x < 0 {
                        particles[i].position.x = UIScreen.main.bounds.width
                    } else if particles[i].position.x > UIScreen.main.bounds.width {
                        particles[i].position.x = 0
                    }
                    
                    if particles[i].position.y < 0 {
                        particles[i].position.y = UIScreen.main.bounds.height
                    } else if particles[i].position.y > UIScreen.main.bounds.height {
                        particles[i].position.y = 0
                    }
                }
            }
        }
    }
}

/// ゲーム用パーティクル構造体
struct NeonGameParticle {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
    let blur: CGFloat
}

/// result.pngフルスクリーン表示ビュー
struct NeonResultFullScreenView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 20) {
                // result.png画像を表示
                Image("result")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                    .frame(maxHeight: UIScreen.main.bounds.height * 0.7)
                    .neonGlow(color: NeonColors.neonPink, radius: 20, intensity: 1.0)
                    .onTapGesture {
                        onDismiss()
                    }
                
                // 閉じるボタン
                Button("閉じる") {
                    onDismiss()
                }
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [NeonColors.neonOrange, NeonColors.neonPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(NeonColors.neonOrange, lineWidth: 2)
                        )
                )
                .neonGlow(color: NeonColors.neonOrange, radius: 12, intensity: 1.0)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: true)
    }
}

#Preview {
    UnifiedGameView()
}
