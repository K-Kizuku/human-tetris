//
//  CameraManager.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import AVFoundation
import CoreVideo
import SwiftUI

protocol CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer)
    func cameraManager(_ manager: CameraManager, didEncounterError error: Error)
}

class CameraManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var permissionGranted = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?

    var delegate: CameraManagerDelegate?

    override init() {
        super.init()
        configureSession()
    }

    deinit {
        stopSession()
    }

    func requestPermission() {
        sessionQueue.async { [weak self] in
            #if targetEnvironment(simulator)
                // シミュレータでは権限を自動的に許可
                DispatchQueue.main.async {
                    self?.permissionGranted = true
                    self?.startSession()
                }
            #else
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .authorized:
                    DispatchQueue.main.async {
                        self?.permissionGranted = true
                        self?.startSession()
                    }
                case .notDetermined:
                    AVCaptureDevice.requestAccess(for: .video) { granted in
                        DispatchQueue.main.async {
                            self?.permissionGranted = granted
                            if granted {
                                self?.startSession()
                            }
                        }
                    }
                case .denied, .restricted:
                    DispatchQueue.main.async {
                        self?.permissionGranted = false
                    }
                @unknown default:
                    DispatchQueue.main.async {
                        self?.permissionGranted = false
                    }
                }
            #endif
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()

            // フルスクリーン撮影のためより高解像度を使用
            if self.captureSession.canSetSessionPreset(.hd1280x720) {
                self.captureSession.sessionPreset = .hd1280x720
            } else if self.captureSession.canSetSessionPreset(.vga640x480) {
                self.captureSession.sessionPreset = .vga640x480
            } else {
                self.captureSession.sessionPreset = .medium
            }

            // 利用可能なカメラデバイスを取得
            var videoDevice: AVCaptureDevice?

            #if targetEnvironment(simulator)
                // シミュレータでは利用可能な任意のビデオデバイスを取得
                let discoverySession = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera, .external],
                    mediaType: .video,
                    position: .unspecified
                )
                videoDevice = discoverySession.devices.first
                print("Simulator: Found \(discoverySession.devices.count) video devices")
            #else
                // 実機では優先順位でカメラを選択
                // 1. リアカメラを試す
                videoDevice = AVCaptureDevice.default(
                    .builtInWideAngleCamera, for: .video, position: .back)

                // 2. フロントカメラを試す
                if videoDevice == nil {
                    videoDevice = AVCaptureDevice.default(
                        .builtInWideAngleCamera, for: .video, position: .front)
                }

                // 3. デフォルトのビデオデバイスを試す
                if videoDevice == nil {
                    videoDevice = AVCaptureDevice.default(for: .video)
                }
            #endif

            guard let videoDevice = videoDevice else {
                print("No video device available - simulator or device configuration issue")
                // シミュレータでカメラが完全に利用できない場合でもクラッシュしないよう続行
                self.captureSession.commitConfiguration()
                return
            }

            print("Using video device: \(videoDevice.localizedName)")

            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)

                if self.captureSession.canAddInput(videoDeviceInput) {
                    self.captureSession.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                } else {
                    print("Couldn't add video device input to the session")
                    self.captureSession.commitConfiguration()
                    return
                }
            } catch {
                print("Couldn't create video device input: \(error)")
                self.captureSession.commitConfiguration()
                return
            }

            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(
                self, queue: DispatchQueue(label: "video.data.output.queue"))
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true

            if self.captureSession.canAddOutput(videoDataOutput) {
                self.captureSession.addOutput(videoDataOutput)
                self.videoDataOutput = videoDataOutput

                if let connection = videoDataOutput.connection(with: .video) {
                    // iOS 17.0以降では videoRotationAngle を使用
                    if #available(iOS 17.0, *) {
                        connection.videoRotationAngle = 90.0  // portrait = 90度回転
                    } else {
                        connection.videoOrientation = .portrait
                    }
                    connection.isVideoMirrored = false
                }
            } else {
                print("Couldn't add video data output to the session")
                self.captureSession.commitConfiguration()
                return
            }

            self.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                self.previewLayer = previewLayer
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }

            self.captureSession.startRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }

            self.captureSession.stopRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    func toggleSession() {
        if isSessionRunning {
            stopSession()
        } else {
            startSession()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        delegate?.cameraManager(self, didOutput: pixelBuffer)
    }

    func captureOutput(
        _ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        print("Frame dropped")
    }
}
