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

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 4) {
                    // Top section - Camera + Countdown (中央配置)
                    HStack {
                        Spacer()
                        cameraSection(geometry: geometry)
                            .frame(height: geometry.size.height * 0.22)  // 25% -> 22%に縮小
                        Spacer()
                    }

                    // Bottom section - Game Board
                    gameBoardSection(geometry: geometry)
                        .frame(height: geometry.size.height * 0.78)  // 75% -> 78%に拡大
                }
                .padding(.horizontal, 6)  // パディングも縮小

                // Flash effect overlay
                if showFlashEffect {
                    Rectangle()
                        .fill(Color.white.opacity(0.8))
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.2), value: showFlashEffect)
                }

                // Success/Failure highlights
                if showSuccessHighlight {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 4)
                        .frame(
                            width: geometry.size.width * 0.8, height: geometry.size.height * 0.22
                        )
                        .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.125)
                        .animation(.bouncy, value: showSuccessHighlight)
                }

                if showFailureHighlight {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red, lineWidth: 4)
                        .frame(
                            width: geometry.size.width * 0.8, height: geometry.size.height * 0.22
                        )
                        .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.125)
                        .animation(.bouncy, value: showFailureHighlight)
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
            .frame(height: geometry.size.height * 0.25)  // カメラ部分の高さを維持
            .frame(width: calculateCameraWidth(for: geometry))  // デバイスアスペクト比に基づく幅
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )

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
                .shadow(color: .cyan, radius: 5) // ネオングロー効果
                
                Spacer()
            }
            .padding(.horizontal, 6)
            
            // Compact control section
            HStack(spacing: 6) {
                // IoU indicator
                HStack(spacing: 2) {
                    Text("IoU:")
                        .foregroundColor(.cyan)
                        .font(.caption2)
                        .shadow(color: .cyan, radius: 2) // ネオングロー
                    ProgressView(value: max(0.0, min(1.0, Double(currentIoU))), total: 1.0)
                        .tint(.green)
                        .frame(width: 30, height: 2)
                        .shadow(color: .green, radius: 3) // ネオングロー
                    Text(String(format: "%.2f", currentIoU))
                        .foregroundColor(.cyan)
                        .font(.caption2)
                        .shadow(color: .cyan, radius: 2) // ネオングロー
                }

                Spacer()

                // Game start/next piece button
                if !isGameActive {
                    Button("開始") {
                        startGame()
                    }
                    .buttonStyle(CompactButtonStyle())
                } else if !countdownManager.isCountingDown {
                    Button("次") {
                        requestNextPiece()
                    }
                    .buttonStyle(CompactButtonStyle())
                }

                Spacer()

                // Stability indicator
                HStack(spacing: 2) {
                    Text("安定:")
                        .foregroundColor(.purple)
                        .font(.caption2)
                        .shadow(color: .purple, radius: 2) // ネオングロー
                    ProgressView(
                        value: max(0.0, min(1.0, Double(captureState.stableMs) / 1000.0)),
                        total: 1.0
                    )
                    .tint(captureState.isStable ? .green : .orange)
                    .frame(width: 30, height: 2)
                    .shadow(color: captureState.isStable ? .green : .orange, radius: 3) // ネオングロー
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 25)  // 固定高さを設定

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
            ForEach(0..<piece.cells.count, id: \.self) { index in
                let cell = piece.cells[index]
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: cellWidth, height: cellHeight)
                    .position(
                        x: (CGFloat(cell.x) + 0.5) * cellWidth,
                        y: (CGFloat(cell.y) + 0.5) * cellHeight
                    )
            }
        }
    }

    @ViewBuilder
    private var countdownOverlay: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 80, height: 80)

            VStack {
                if countdownManager.currentCount > 0 {
                    Text("\(countdownManager.currentCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("📸")
                        .font(.system(size: 36))
                }

                // Progress ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(countdownManager.progress))
                    .stroke(Color.green, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
            }
        }
    }

    // MARK: - Game Board Section

    @ViewBuilder
    private func gameBoardSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 4) {
            // Score display - more compact for vertical layout
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("スコア: \(gameCore.gameState.score)")
                        .foregroundColor(.yellow)
                        .font(.caption)
                        .shadow(color: .yellow, radius: 3) // ネオングロー
                    Text("ライン: \(gameCore.gameState.linesCleared)")
                        .foregroundColor(.cyan)
                        .font(.caption2)
                        .shadow(color: .cyan, radius: 2) // ネオングロー
                }

                Spacer()

                VStack(alignment: .center, spacing: 1) {
                    Text("レベル: \(gameCore.gameState.level)")
                        .foregroundColor(.green)
                        .font(.caption)
                        .shadow(color: .green, radius: 3) // ネオングロー
                    Text("多様性: \(String(format: "%.1f", shapeHistoryManager.diversityScore))")
                        .foregroundColor(.purple)
                        .font(.caption2)
                        .shadow(color: .purple, radius: 2) // ネオングロー
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Button(isGameActive ? "一時停止" : "再開") {
                        toggleGamePause()
                    }
                    .buttonStyle(CompactButtonStyle())

                    Button("戻る") {
                        dismiss()
                    }
                    .buttonStyle(CompactButtonStyle())
                }
            }
            .padding(.horizontal, 6)
            .frame(height: 40)  // 固定高さを設定

            // Game board - adjusted for better layout
            GameBoardView(
                gameCore: gameCore,
                targetSize: CGSize(
                    width: geometry.size.width * 0.85, height: geometry.size.height * 0.45)
            )
            .frame(maxHeight: geometry.size.height * 0.45)

            // Game controls for vertical layout - more compact
            VStack(spacing: 4) {
                // 上段：左、回転、右
                HStack(spacing: 16) {
                    Button("←") {
                        _ = gameCore.movePiece(dx: -1)
                    }
                    .buttonStyle(CompactControlButtonStyle())

                    Button("↻") {
                        _ = gameCore.rotatePiece()
                    }
                    .buttonStyle(CompactControlButtonStyle())

                    Button("→") {
                        _ = gameCore.movePiece(dx: 1)
                    }
                    .buttonStyle(CompactControlButtonStyle())
                }

                // 下段：ソフトドロップとハードドロップ
                HStack(spacing: 16) {
                    // ソフトドロップボタン（長押し対応）
                    Button("↓") {
                        // タップ時は1回だけ下に移動
                        _ = gameCore.movePiece(dx: 0, dy: 1)
                    }
                    .buttonStyle(CompactSoftDropButtonStyle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                gameCore.startSoftDrop()
                            }
                            .onEnded { _ in
                                gameCore.stopSoftDrop()
                            }
                    )

                    Spacer()

                    // ハードドロップボタン
                    Button("⬇") {
                        gameCore.hardDrop()
                    }
                    .buttonStyle(CompactHardDropButtonStyle())
                }
            }
            .padding(.top, 4)
            .frame(height: 80)  // 固定高さを設定
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

// MARK: - Button Styles

// MARK: - Compact Button Styles for Better Layout

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

#Preview {
    UnifiedGameView()
}
