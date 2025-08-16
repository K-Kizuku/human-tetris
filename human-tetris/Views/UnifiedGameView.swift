//
//  UnifiedGameView.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI
import AVFoundation
import Vision

struct UnifiedGameView: View, GamePieceProvider {
    @StateObject private var cameraManager = CameraManager()
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
                
                VStack(spacing: 8) {
                    // Top section - Camera + Countdown
                    cameraSection(geometry: geometry)
                        .frame(height: geometry.size.height * 0.25)
                    
                    // Bottom section - Game Board
                    gameBoardSection(geometry: geometry)
                    .frame(height: geometry.size.height * 0.75)
                }
                .padding(.horizontal, 8)
                
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
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.22)
                        .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.125)
                        .animation(.bouncy, value: showSuccessHighlight)
                }
                
                if showFailureHighlight {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red, lineWidth: 4)
                        .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.22)
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
    
    @ViewBuilder
    private func cameraSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 4) {
            // Camera and overlays
            ZStack {
                // Camera preview
                if let previewLayer = cameraManager.previewLayer {
                    CameraPreview(previewLayer: previewLayer)
                        .onAppear {
                            setupCamera()
                            updateROIFrame(for: geometry.size)
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            updateROIFrame(for: newSize)
                        }
                } else {
                    // Camera unavailable fallback
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("カメラ未対応")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                        )
                        .onAppear {
                            setupCamera()
                            updateROIFrame(for: geometry.size)
                        }
                }
                
                // 4x3 Grid overlay
                Grid4x3Overlay(roiFrame: roiFrame)
                
                // Occupancy heatmap
                OccupancyHeatmap(
                    grid: captureState.grid,
                    roiFrame: roiFrame
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
            .frame(height: geometry.size.height * 0.18) // カメラ部分を18%に調整
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            
            // Compact control section
            HStack(spacing: 8) {
                // IoU indicator
                HStack(spacing: 4) {
                    Text("IoU:")
                        .foregroundColor(.white)
                        .font(.caption2)
                    ProgressView(value: max(0.0, min(1.0, Double(currentIoU))), total: 1.0)
                        .tint(.green)
                        .frame(width: 40, height: 2)
                    Text(String(format: "%.2f", currentIoU))
                        .foregroundColor(.white)
                        .font(.caption2)
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
                HStack(spacing: 4) {
                    Text("安定:")
                        .foregroundColor(.white)
                        .font(.caption2)
                    ProgressView(value: max(0.0, min(1.0, Double(captureState.stableMs) / 1000.0)), total: 1.0)
                        .tint(captureState.isStable ? .green : .orange)
                        .frame(width: 40, height: 2)
                }
            }
            .padding(.horizontal, 8)
            
            #if targetEnvironment(simulator)
            if cameraManager.previewLayer == nil {
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
        let cellWidth = roiFrame.width / 3
        let cellHeight = roiFrame.height / 4
        
        ZStack {
            ForEach(0..<piece.cells.count, id: \.self) { index in
                let cell = piece.cells[index]
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: cellWidth, height: cellHeight)
                    .position(
                        x: roiFrame.minX + (CGFloat(cell.x) + 0.5) * cellWidth,
                        y: roiFrame.minY + (CGFloat(cell.y) + 0.5) * cellHeight
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
        VStack(spacing: 8) {
            // Score display - more compact for vertical layout
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("スコア: \(gameCore.gameState.score)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                    Text("ライン: \(gameCore.gameState.linesCleared)")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("レベル: \(gameCore.gameState.level)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                    Text("多様性: \(String(format: "%.1f", shapeHistoryManager.diversityScore))")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
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
            .padding(.horizontal, 8)
            
            // Game board - larger for vertical layout
            GameBoardView(gameCore: gameCore, targetSize: CGSize(width: geometry.size.width * 0.85, height: geometry.size.height * 0.55))
                .frame(maxHeight: geometry.size.height * 0.55)
            
            // Game controls for vertical layout
            HStack(spacing: 12) {
                Button("←") {
                    _ = gameCore.movePiece(dx: -1)
                }
                .buttonStyle(ControlButtonStyle())
                
                Button("↻") {
                    _ = gameCore.rotatePiece()
                }
                .buttonStyle(ControlButtonStyle())
                
                Button("→") {
                    _ = gameCore.movePiece(dx: 1)
                }
                .buttonStyle(ControlButtonStyle())
            }
            .padding(.top, 8)
        }
    }
    
    
    // MARK: - Setup and Lifecycle
    
    private func setupComponents() {
        print("UnifiedGameView: Setting up components")
        
        // Setup camera
        cameraManager.delegate = self
        cameraManager.requestPermission()
        
        // Setup vision processor
        visionProcessor.delegate = self
        
        // Setup countdown manager
        countdownManager.delegate = self
        
        // Setup game core
        gameCore.setPieceProvider(self)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateROIFrame()
        }
    }
    
    private func cleanupComponents() {
        print("UnifiedGameView: Cleaning up components")
        cameraManager.stopSession()
        countdownManager.stopCountdown()
    }
    
    private func updateROIFrame() {
        guard let previewLayer = cameraManager.previewLayer else { return }
        updateROIFrame(for: previewLayer.bounds.size)
    }
    
    private func updateROIFrame(for bounds: CGSize) {
        // 垂直レイアウト: カメラセクションが上部25%を使用
        let cameraHeight = bounds.height * 0.25
        let targetAspectRatio: CGFloat = 3.0 / 4.0 // 4x3グリッド (幅:高さ = 3:4)
        
        let sideMargin: CGFloat = 16
        let topMargin: CGFloat = 20
        let bottomMargin: CGFloat = 40
        
        let availableWidth = bounds.width - (sideMargin * 2)
        let availableHeight = cameraHeight * 0.72 - topMargin - bottomMargin // カメラ部分18%を使用
        
        var frameWidth: CGFloat
        var frameHeight: CGFloat
        
        if availableWidth / availableHeight > targetAspectRatio {
            frameHeight = availableHeight
            frameWidth = frameHeight * targetAspectRatio
        } else {
            frameWidth = availableWidth
            frameHeight = frameWidth / targetAspectRatio
        }
        
        // フレームを画面中央上部に配置
        roiFrame = CGRect(
            x: (bounds.width - frameWidth) / 2,
            y: topMargin + (availableHeight - frameHeight) / 2,
            width: frameWidth,
            height: frameHeight
        )
        
        print("UnifiedGameView: ROI frame set to \(roiFrame) for vertical layout")
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
            (x: 1, y: 2)
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
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        cameraManager.delegate = self
        cameraManager.requestPermission()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateROIFrame()
        }
    }
}

// MARK: - GamePieceProvider

extension UnifiedGameView {
    func requestNextPiece(completion: @escaping (Polyomino?) -> Void) {
        print("UnifiedGameView: GamePieceProvider requestNextPiece called")
        
        DispatchQueue.global(qos: .userInitiated).async {
            if self.captureState.isStable && self.currentIoU >= 0.6,
               let extractedPiece = self.shapeExtractor.extractBestShape(from: self.captureState.grid) {
                
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
        return visionProcessor.detectionEnabled && cameraManager.isSessionRunning
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
                print("UnifiedGameView: Successfully captured piece at zero: \(extractedPiece.cells.count) cells")
                return extractedPiece
            } else {
                print("UnifiedGameView: Validation failed: \(validation.errorMessage ?? "Unknown error")")
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

// MARK: - CameraManagerDelegate

extension UnifiedGameView: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer) {
        visionProcessor.processFrame(pixelBuffer)
    }
    
    func cameraManager(_ manager: CameraManager, didEncounterError error: Error) {
        print("UnifiedGameView: Camera error: \(error)")
    }
}

// MARK: - VisionProcessorDelegate

extension UnifiedGameView: VisionProcessorDelegate {
    func visionProcessor(_ processor: VisionProcessor, didDetectPersonMask mask: CVPixelBuffer, in roi: CGRect) {
        let grid = quantizationProcessor.quantize(
            mask: mask,
            roi: roi,
            threshold: quantizationProcessor.getAdaptiveThreshold()
        )
        
        DispatchQueue.main.async {
            self.captureState.grid = grid
            
            if let candidate = self.shapeExtractor.extractBestShape(from: grid) {
                self.currentIoU = Float(candidate.cells.count) / 4.0 // Simplified IoU calculation
                self.captureState.iou = self.currentIoU
                self.captureState.stableMs = Int(self.quantizationProcessor.stableTime * 1000)
            }
        }
    }
    
    func visionProcessor(_ processor: VisionProcessor, didDetectPose pose: VNHumanBodyPoseObservation) {
        // Additional pose validation if needed
    }
    
    func visionProcessor(_ processor: VisionProcessor, didEncounterError error: Error) {
        print("UnifiedGameView: Vision processing error: \(error)")
    }
}

// MARK: - Button Styles

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
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    UnifiedGameView()
}