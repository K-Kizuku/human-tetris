//
//  MultiCameraManager.swift
//  human-tetris
//
//  Created by Kiro on 2025/08/17.
//

import AVFoundation
import CoreVideo
import SwiftUI

protocol MultiCameraManagerDelegate {
    func multiCameraManager(
        _ manager: MultiCameraManager, didOutputBackCamera pixelBuffer: CVPixelBuffer)
    func multiCameraManager(
        _ manager: MultiCameraManager, didOutputFrontCamera pixelBuffer: CVPixelBuffer)
    func multiCameraManager(_ manager: MultiCameraManager, didEncounterError error: Error)
}

class MultiCameraManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var permissionGranted = false
    @Published var backCameraPreviewLayer: AVCaptureVideoPreviewLayer?
    @Published var frontCameraPreviewLayer: AVCaptureVideoPreviewLayer?
    @Published var isMultiCamSupported = false

    var delegate: MultiCameraManagerDelegate?

    private var multiCamSession: AVCaptureMultiCamSession?
    private let sessionQueue = DispatchQueue(label: "multi.camera.session.queue")

    // 背面カメラ関連
    private var backCameraDeviceInput: AVCaptureDeviceInput?
    private var backCameraVideoDataOutput: AVCaptureVideoDataOutput?

    // 前面カメラ関連
    private var frontCameraDeviceInput: AVCaptureDeviceInput?
    private var frontCameraVideoDataOutput: AVCaptureVideoDataOutput?

    override init() {
        super.init()
        checkMultiCamSupport()
        configureSession()
    }

    deinit {
        stopSession()
    }

    private func checkMultiCamSupport() {
        isMultiCamSupported = AVCaptureMultiCamSession.isMultiCamSupported
        print("MultiCameraManager: Multi-cam support: \(isMultiCamSupported)")
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

            if self.isMultiCamSupported {
                self.configureMultiCamSession()
            } else {
                self.configureFallbackSession()
            }
        }
    }

    private func configureMultiCamSession() {
        let session = AVCaptureMultiCamSession()
        session.beginConfiguration()

        // セッションプリセットを設定
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        }

        // 背面カメラの設定
        if let backCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back)
        {
            do {
                let backCameraInput = try AVCaptureDeviceInput(device: backCamera)
                if session.canAddInput(backCameraInput) {
                    session.addInputWithNoConnections(backCameraInput)
                    self.backCameraDeviceInput = backCameraInput

                    // 背面カメラの出力設定
                    let backCameraOutput = AVCaptureVideoDataOutput()
                    backCameraOutput.setSampleBufferDelegate(
                        self, queue: DispatchQueue(label: "back.camera.output.queue"))
                    backCameraOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    backCameraOutput.alwaysDiscardsLateVideoFrames = true

                    if session.canAddOutput(backCameraOutput) {
                        session.addOutputWithNoConnections(backCameraOutput)
                        self.backCameraVideoDataOutput = backCameraOutput

                        // 背面カメラの接続を作成
                        let backCameraConnection = AVCaptureConnection(
                            inputPorts: backCameraInput.ports, output: backCameraOutput)
                        if session.canAddConnection(backCameraConnection) {
                            session.addConnection(backCameraConnection)

                            if #available(iOS 17.0, *) {
                                backCameraConnection.videoRotationAngle = 90.0
                            } else {
                                backCameraConnection.videoOrientation = .portrait
                            }
                        }
                    }
                }
            } catch {
                print("MultiCameraManager: Error setting up back camera: \(error)")
            }
        }

        // 前面カメラの設定
        if let frontCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front)
        {
            do {
                let frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                if session.canAddInput(frontCameraInput) {
                    session.addInputWithNoConnections(frontCameraInput)
                    self.frontCameraDeviceInput = frontCameraInput

                    // 前面カメラの出力設定
                    let frontCameraOutput = AVCaptureVideoDataOutput()
                    frontCameraOutput.setSampleBufferDelegate(
                        self, queue: DispatchQueue(label: "front.camera.output.queue"))
                    frontCameraOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    frontCameraOutput.alwaysDiscardsLateVideoFrames = true

                    if session.canAddOutput(frontCameraOutput) {
                        session.addOutputWithNoConnections(frontCameraOutput)
                        self.frontCameraVideoDataOutput = frontCameraOutput

                        // 前面カメラの接続を作成
                        let frontCameraConnection = AVCaptureConnection(
                            inputPorts: frontCameraInput.ports, output: frontCameraOutput)
                        if session.canAddConnection(frontCameraConnection) {
                            session.addConnection(frontCameraConnection)

                            if #available(iOS 17.0, *) {
                                frontCameraConnection.videoRotationAngle = 90.0
                            } else {
                                frontCameraConnection.videoOrientation = .portrait
                            }
                            frontCameraConnection.isVideoMirrored = true
                        }
                    }
                }
            } catch {
                print("MultiCameraManager: Error setting up front camera: \(error)")
            }
        }

        session.commitConfiguration()
        self.multiCamSession = session

        // プレビューレイヤーの作成
        DispatchQueue.main.async {
            if let backCameraInput = self.backCameraDeviceInput {
                let backPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
                let backPreviewConnection = AVCaptureConnection(
                    inputPort: backCameraInput.ports.first!, videoPreviewLayer: backPreviewLayer)
                if session.canAddConnection(backPreviewConnection) {
                    session.addConnection(backPreviewConnection)
                    backPreviewLayer.videoGravity = .resizeAspectFill
                    self.backCameraPreviewLayer = backPreviewLayer
                }
            }

            if let frontCameraInput = self.frontCameraDeviceInput {
                let frontPreviewLayer = AVCaptureVideoPreviewLayer(sessionWithNoConnection: session)
                let frontPreviewConnection = AVCaptureConnection(
                    inputPort: frontCameraInput.ports.first!, videoPreviewLayer: frontPreviewLayer)
                if session.canAddConnection(frontPreviewConnection) {
                    session.addConnection(frontPreviewConnection)
                    frontPreviewLayer.videoGravity = .resizeAspectFill
                    frontPreviewConnection.isVideoMirrored = true
                    self.frontCameraPreviewLayer = frontPreviewLayer
                }
            }
        }
    }

    private func configureFallbackSession() {
        // マルチカメラがサポートされていない場合は背面カメラのみを使用
        print("MultiCameraManager: Multi-cam not supported, using back camera only")

        let session = AVCaptureSession()
        session.beginConfiguration()

        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        }

        // 背面カメラのみ設定
        if let backCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back)
        {
            do {
                let backCameraInput = try AVCaptureDeviceInput(device: backCamera)
                if session.canAddInput(backCameraInput) {
                    session.addInput(backCameraInput)
                    self.backCameraDeviceInput = backCameraInput

                    let backCameraOutput = AVCaptureVideoDataOutput()
                    backCameraOutput.setSampleBufferDelegate(
                        self, queue: DispatchQueue(label: "back.camera.output.queue"))
                    backCameraOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    backCameraOutput.alwaysDiscardsLateVideoFrames = true

                    if session.canAddOutput(backCameraOutput) {
                        session.addOutput(backCameraOutput)
                        self.backCameraVideoDataOutput = backCameraOutput

                        if let connection = backCameraOutput.connection(with: .video) {
                            if #available(iOS 17.0, *) {
                                connection.videoRotationAngle = 90.0
                            } else {
                                connection.videoOrientation = .portrait
                            }
                        }
                    }
                }
            } catch {
                print("MultiCameraManager: Error setting up fallback camera: \(error)")
            }
        }

        session.commitConfiguration()

        // 通常のセッションをマルチカメラセッションとして扱う
        self.multiCamSession = session as? AVCaptureMultiCamSession

        DispatchQueue.main.async {
            let backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            backPreviewLayer.videoGravity = .resizeAspectFill
            self.backCameraPreviewLayer = backPreviewLayer
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.multiCamSession, !session.isRunning else {
                return
            }

            session.startRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = session.isRunning
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.multiCamSession, session.isRunning else {
                return
            }

            session.stopRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension MultiCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // どのカメラからの出力かを判定
        if output == backCameraVideoDataOutput {
            delegate?.multiCameraManager(self, didOutputBackCamera: pixelBuffer)
        } else if output == frontCameraVideoDataOutput {
            delegate?.multiCameraManager(self, didOutputFrontCamera: pixelBuffer)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        print(
            "MultiCameraManager: Frame dropped from \(output == backCameraVideoDataOutput ? "back" : "front") camera"
        )
    }
}
