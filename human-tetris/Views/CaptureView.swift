//
//  CaptureView.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI
import AVFoundation
import Vision

struct CaptureView: View, GamePieceProvider {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var visionProcessor = VisionProcessor()
    @StateObject private var quantizationProcessor = QuantizationProcessor()
    @StateObject private var shapeExtractor = ShapeExtractor()
    @StateObject private var gameCore = GameCore()
    
    @State private var roiFrame = CGRect(x: 100, y: 200, width: 200, height: 150)
    @State private var currentIoU: Float = 0.0
    @State private var showingGame = false
    @State private var detectedPiece: Polyomino?
    @State private var pendingPieceRequests: [((Polyomino?) -> Void)] = []
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let previewLayer = cameraManager.previewLayer {
                CameraPreview(previewLayer: previewLayer)
                    .onAppear {
                        setupCamera()
                    }
                    .onDisappear {
                        cameraManager.stopSession()
                    }
            } else {
                // カメラが利用できない場合の代替表示
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white.opacity(0.7))
                            Text("カメラ未対応")
                                .font(.title2)
                                .foregroundColor(.white)
                            Text("シミュレータまたはカメラが利用できません")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                    )
                    .onAppear {
                        setupCamera()
                    }
            }
            
            VStack {
                Spacer()
                
                ZStack {
                    Grid4x3Overlay(roiFrame: roiFrame)
                    
                    OccupancyHeatmap(
                        grid: quantizationProcessor.currentGrid,
                        roiFrame: roiFrame
                    )
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("IoU: \(String(format: "%.2f", currentIoU))")
                                .foregroundColor(.white)
                                .font(.caption)
                            
                            ProgressView(value: max(0.0, min(1.0, Double(currentIoU))), total: 1.0)
                                .tint(.green)
                                .frame(height: 4)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("安定: \(String(format: "%.1f", quantizationProcessor.stableTime))s")
                                .foregroundColor(.white)
                                .font(.caption)
                            
                            ProgressView(value: max(0.0, min(1.0, quantizationProcessor.stableTime)), total: 1.0)
                                .tint(quantizationProcessor.isStable ? .green : .orange)
                                .frame(height: 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    if quantizationProcessor.isStable && currentIoU >= 0.6 {
                        Button("ピース確定") {
                            confirmPiece()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .animation(.bouncy, value: quantizationProcessor.isStable)
                    }
                    
                    #if targetEnvironment(simulator)
                    // シミュレータ用のテストボタン
                    if cameraManager.previewLayer == nil {
                        Button("テストピース生成") {
                            generateTestPiece()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    #endif
                    
                    HStack {
                        Button("戻る") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Spacer()
                        
                        Button(visionProcessor.detectionEnabled ? "一時停止" : "再開") {
                            visionProcessor.toggleDetection()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            setupProcessors()
        }
        .sheet(isPresented: $showingGame) {
            if let piece = detectedPiece {
                GameView(gameCore: gameCore, initialPiece: piece, pieceProvider: self)
            }
        }
        .onChange(of: showingGame) { _, isShowing in
            if isShowing {
                print("CaptureView: GameView showing - stopping camera and vision processing")
                stopProcessing()
            } else {
                print("CaptureView: GameView hidden - resuming camera and vision processing")  
                resumeProcessing()
            }
        }
    }
    
    private func setupCamera() {
        cameraManager.delegate = self
        cameraManager.requestPermission()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            updateROIFrame()
        }
    }
    
    private func setupProcessors() {
        visionProcessor.delegate = self
    }
    
    private func updateROIFrame() {
        guard let previewLayer = cameraManager.previewLayer else { return }
        
        let bounds = previewLayer.bounds
        
        // 4x3アスペクト比を維持しつつデバイスサイズに適応
        let targetAspectRatio: CGFloat = 3.0 / 4.0 // width/height = 3/4
        let maxWidthRatio: CGFloat = 0.7
        let maxHeightRatio: CGFloat = 0.6
        
        let maxWidth = bounds.width * maxWidthRatio
        let maxHeight = bounds.height * maxHeightRatio
        
        var frameWidth: CGFloat
        var frameHeight: CGFloat
        
        // アスペクト比を保持しながら最大サイズ内に収める
        if maxWidth / maxHeight > targetAspectRatio {
            // 高さが制限要因
            frameHeight = maxHeight
            frameWidth = frameHeight * targetAspectRatio
        } else {
            // 幅が制限要因
            frameWidth = maxWidth
            frameHeight = frameWidth / targetAspectRatio
        }
        
        roiFrame = CGRect(
            x: (bounds.width - frameWidth) / 2,
            y: (bounds.height - frameHeight) / 2,
            width: frameWidth,
            height: frameHeight
        )
    }
    
    private func confirmPiece() {
        print("CaptureView: confirmPiece() called")
        
        // 現在のグリッドから直接抽出を試行
        let currentGrid = quantizationProcessor.currentGrid
        print("CaptureView: Current grid on cells: \(currentGrid.onCells.count)")
        
        if let extractedPiece = shapeExtractor.extractBestShape(from: currentGrid) {
            print("CaptureView: Successfully extracted piece with \(extractedPiece.cells.count) cells")
            detectedPiece = extractedPiece
            showingGame = true
            print("CaptureView: showingGame = \(showingGame)")
        } else {
            print("CaptureView: No valid piece could be extracted from current grid")
            // フォールバック: テストピースを生成
            #if targetEnvironment(simulator)
            generateTestPiece()
            #else
            print("CaptureView: Cannot extract piece, try adjusting pose")
            #endif
        }
    }
    
    #if targetEnvironment(simulator)
    private func generateTestPiece() {
        print("CaptureView: generateTestPiece() called")
        // シミュレータ用のテストピース（L字型）
        let testPiece = Polyomino(cells: [
            (x: 0, y: 0),
            (x: 0, y: 1),
            (x: 0, y: 2),
            (x: 1, y: 2)
        ])
        
        print("CaptureView: Setting test piece and showing game")
        detectedPiece = testPiece
        showingGame = true
        print("CaptureView: showingGame = \(showingGame)")
    }
    #endif
    
    // MARK: - GamePieceProvider
    
    func requestNextPiece(completion: @escaping (Polyomino?) -> Void) {
        print("CaptureView: requestNextPiece called")
        
        // 非同期で処理してデッドロックを防ぐ
        DispatchQueue.global(qos: .userInitiated).async {
            // 既に検出済みのピースがある場合は即座に返す
            if self.quantizationProcessor.isStable && self.currentIoU >= 0.6,
               let candidate = self.shapeExtractor.bestCandidate {
                DispatchQueue.main.async {
                    completion(candidate.toPolyomino())
                }
                return
            }
            
            // 待機中のリクエストに追加
            DispatchQueue.main.async {
                self.pendingPieceRequests.append(completion)
            }
            
            // タイムアウト処理
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.timeoutPieceRequest()
            }
        }
    }
    
    func isAvailable() -> Bool {
        return visionProcessor.detectionEnabled && cameraManager.isSessionRunning
    }
    
    private func timeoutPieceRequest() {
        if !pendingPieceRequests.isEmpty {
            // タイムアウトした場合はフォールバックピースを返す
            let fallbackPiece = generateFallbackPiece()
            for request in pendingPieceRequests {
                request(fallbackPiece)
            }
            pendingPieceRequests.removeAll()
        }
    }
    
    private func generateFallbackPiece() -> Polyomino {
        let shapes: [[(x: Int, y: Int)]] = [
            [(0, 0), (0, 1), (0, 2), (0, 3)], // I型
            [(0, 0), (0, 1), (0, 2), (1, 2)], // L型
            [(0, 1), (1, 0), (1, 1), (1, 2)], // T型
            [(0, 0), (0, 1), (1, 1), (1, 2)], // Z型
        ]
        let randomShape = shapes.randomElement() ?? shapes[0]
        return Polyomino(cells: randomShape)
    }
    
    private func stopProcessing() {
        print("CaptureView: Stopping camera and vision processing")
        // Vision処理のみ停止、UIの状態は変更しない
        if visionProcessor.detectionEnabled {
            visionProcessor.toggleDetection()
        }
        cameraManager.stopSession()
    }
    
    private func resumeProcessing() {
        print("CaptureView: Resuming camera and vision processing")
        cameraManager.startSession()
        // Vision処理を再開
        if !visionProcessor.detectionEnabled {
            visionProcessor.toggleDetection()
        }
    }
    
    private func fulfillPendingRequests(with piece: Polyomino) {
        for request in pendingPieceRequests {
            request(piece)
        }
        pendingPieceRequests.removeAll()
    }
}

// MARK: - CameraManagerDelegate

extension CaptureView: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer) {
        visionProcessor.processFrame(pixelBuffer)
    }
    
    func cameraManager(_ manager: CameraManager, didEncounterError error: Error) {
        print("Camera error: \(error)")
    }
}

// MARK: - VisionProcessorDelegate

extension CaptureView: VisionProcessorDelegate {
    func visionProcessor(_ processor: VisionProcessor, didDetectPersonMask mask: CVPixelBuffer, in roi: CGRect) {
        let grid = quantizationProcessor.quantize(
            mask: mask,
            roi: roi,
            threshold: quantizationProcessor.getAdaptiveThreshold()
        )
        
        if shapeExtractor.extractBestShape(from: grid) != nil {
            DispatchQueue.main.async {
                if let candidate = self.shapeExtractor.bestCandidate {
                    self.currentIoU = candidate.iou
                    
                    // 新しいピースが検出され、待機中のリクエストがある場合は満たす
                    if self.quantizationProcessor.isStable && self.currentIoU >= 0.6 && !self.pendingPieceRequests.isEmpty {
                        let detectedPiece = candidate.toPolyomino()
                        self.fulfillPendingRequests(with: detectedPiece)
                    }
                }
            }
        }
    }
    
    func visionProcessor(_ processor: VisionProcessor, didDetectPose pose: VNHumanBodyPoseObservation) {
        // ポーズ情報を使用した追加の検証やヒント生成に使用可能
    }
    
    func visionProcessor(_ processor: VisionProcessor, didEncounterError error: Error) {
        print("Vision processing error: \(error)")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                configuration.isPressed ? Color.green.opacity(0.8) : Color.green
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                configuration.isPressed ? Color.gray.opacity(0.8) : Color.gray.opacity(0.7)
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    CaptureView()
}