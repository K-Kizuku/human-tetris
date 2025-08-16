//
//  VisionProcessor.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Accelerate
import CoreImage
import CoreVideo
import Vision

protocol VisionProcessorDelegate {
    func visionProcessor(
        _ processor: VisionProcessor, didDetectPersonMask mask: CVPixelBuffer, in roi: CGRect)
    func visionProcessor(
        _ processor: VisionProcessor, didDetectPose pose: VNHumanBodyPoseObservation)
    func visionProcessor(_ processor: VisionProcessor, didEncounterError error: Error)
}

class VisionProcessor: ObservableObject, GamePieceProvider, CameraManagerDelegate {
    var delegate: VisionProcessorDelegate?

    private let visionQueue = DispatchQueue(label: "vision.processing.queue", qos: .userInteractive)
    private let personSegmentationRequest: VNGeneratePersonSegmentationRequest
    private let poseDetectionRequest: VNDetectHumanBodyPoseRequest

    private var frameCount = 0
    private let processingInterval = 2

    @Published var isProcessing = false
    @Published var detectionEnabled = true

    // ROIフレーム（UIKit座標系）
    var roiFrame: CGRect = .zero
    var previewLayerBounds: CGRect = .zero

    init() {
        personSegmentationRequest = VNGeneratePersonSegmentationRequest()
        personSegmentationRequest.qualityLevel = .balanced
        personSegmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8

        poseDetectionRequest = VNDetectHumanBodyPoseRequest()
    }

    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard detectionEnabled else { return }

        frameCount += 1
        if frameCount % processingInterval != 0 {
            return
        }

        visionQueue.async { [weak self] in
            self?.performVisionProcessing(on: pixelBuffer)
        }
    }

    private func performVisionProcessing(on pixelBuffer: CVPixelBuffer) {
        DispatchQueue.main.async {
            self.isProcessing = true
        }

        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try imageRequestHandler.perform([personSegmentationRequest, poseDetectionRequest])

            if let personSegmentationResult = personSegmentationRequest.results?.first {
                processPersonSegmentation(personSegmentationResult, originalBuffer: pixelBuffer)
            }

            if let poseResult = poseDetectionRequest.results?.first {
                processPoseDetection(poseResult)
            }

        } catch {
            DispatchQueue.main.async {
                self.delegate?.visionProcessor(self, didEncounterError: error)
            }
        }

        DispatchQueue.main.async {
            self.isProcessing = false
        }
    }

    private func processPersonSegmentation(
        _ result: VNPixelBufferObservation, originalBuffer: CVPixelBuffer
    ) {
        let maskBuffer = result.pixelBuffer

        // UIKit座標系のROIフレームをVision座標系（ピクセル座標）に変換
        let imageWidth = CVPixelBufferGetWidth(originalBuffer)
        let imageHeight = CVPixelBufferGetHeight(originalBuffer)

        let roi: CGRect
        if roiFrame != .zero && previewLayerBounds != .zero {
            // UIKit座標系からピクセル座標系への変換
            let scaleX = CGFloat(imageWidth) / previewLayerBounds.width
            let scaleY = CGFloat(imageHeight) / previewLayerBounds.height

            roi = CGRect(
                x: roiFrame.origin.x * scaleX,
                y: roiFrame.origin.y * scaleY,
                width: roiFrame.width * scaleX,
                height: roiFrame.height * scaleY
            )

            print("VisionProcessor: Converted ROI from UIKit \(roiFrame) to pixel \(roi)")
        } else {
            // フォールバック：画像中央の3:4領域を使用
            let roiWidth = imageWidth * 3 / 5  // より大きな領域を使用
            let roiHeight = imageHeight * 4 / 5
            let roiX = (imageWidth - roiWidth) / 2
            let roiY = (imageHeight - roiHeight) / 2

            roi = CGRect(x: roiX, y: roiY, width: roiWidth, height: roiHeight)
            print("VisionProcessor: Using fallback ROI: \(roi)")
        }

        DispatchQueue.main.async {
            self.delegate?.visionProcessor(self, didDetectPersonMask: maskBuffer, in: roi)
        }
    }

    func updateROI(frame: CGRect, previewBounds: CGRect) {
        roiFrame = frame
        previewLayerBounds = previewBounds
        print("VisionProcessor: Updated ROI frame to \(frame) with preview bounds \(previewBounds)")
    }

    private func processPoseDetection(_ result: VNHumanBodyPoseObservation) {
        DispatchQueue.main.async {
            self.delegate?.visionProcessor(self, didDetectPose: result)
        }
    }

    func toggleDetection() {
        detectionEnabled.toggle()
    }

    func setProcessingInterval(_ interval: Int) {
        guard interval > 0 else { return }
        // processingInterval = interval  // This would need to be a variable property
    }
}

// MARK: - GamePieceProvider

extension VisionProcessor {
    func generateNextPiece() -> Polyomino {
        // デフォルトのTピースを返す（実際の実装では人物認識結果を使用）
        return Polyomino(cells: [
            GridPosition(x: 1, y: 0),
            GridPosition(x: 0, y: 1),
            GridPosition(x: 1, y: 1),
            GridPosition(x: 2, y: 1),
        ])
    }

    func isReady() -> Bool {
        return !isProcessing
    }
}
