//
//  VisionProcessor.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Vision
import CoreVideo
import CoreImage
import Accelerate

protocol VisionProcessorDelegate {
    func visionProcessor(_ processor: VisionProcessor, didDetectPersonMask mask: CVPixelBuffer, in roi: CGRect)
    func visionProcessor(_ processor: VisionProcessor, didDetectPose pose: VNHumanBodyPoseObservation)
    func visionProcessor(_ processor: VisionProcessor, didEncounterError error: Error)
}

class VisionProcessor: ObservableObject {
    var delegate: VisionProcessorDelegate?
    
    private let visionQueue = DispatchQueue(label: "vision.processing.queue", qos: .userInteractive)
    private let personSegmentationRequest: VNGeneratePersonSegmentationRequest
    private let poseDetectionRequest: VNDetectHumanBodyPoseRequest
    
    private var frameCount = 0
    private let processingInterval = 2
    
    @Published var isProcessing = false
    @Published var detectionEnabled = true
    
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
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
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
    
    private func processPersonSegmentation(_ result: VNPixelBufferObservation, originalBuffer: CVPixelBuffer) {
        let maskBuffer = result.pixelBuffer
        
        let imageWidth = CVPixelBufferGetWidth(originalBuffer)
        let imageHeight = CVPixelBufferGetHeight(originalBuffer)
        
        let roiWidth = imageWidth / 3
        let roiHeight = imageHeight / 2
        let roiX = (imageWidth - roiWidth) / 2
        let roiY = (imageHeight - roiHeight) / 2
        
        let roi = CGRect(x: roiX, y: roiY, width: roiWidth, height: roiHeight)
        
        DispatchQueue.main.async {
            self.delegate?.visionProcessor(self, didDetectPersonMask: maskBuffer, in: roi)
        }
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