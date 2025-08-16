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
    func multiCameraManager(_ manager: MultiCameraManager, didEncounterError error: Error)
}

class MultiCameraManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var permissionGranted = false
    @Published var backCameraPreviewLayer: AVCaptureVideoPreviewLayer?
    // 前面カメラのプレビューはARKitが管理
    @Published var isMultiCamSupported = false

    var delegate: MultiCameraManagerDelegate?

    private var captureSession: AVCaptureSession?
    // 背面カメラを最高優先度で実行して30fps維持
    private let sessionQueue = DispatchQueue(label: "multi.camera.session.queue", qos: .userInteractive)

    // 背面カメラ関連
    private var backCameraDeviceInput: AVCaptureDeviceInput?
    private var backCameraVideoDataOutput: AVCaptureVideoDataOutput?

    // 前面カメラはARKitが管理するため削除

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
        // ARKitが前面カメラを使用するため、背面カメラのみを使用
        print("MultiCameraManager: Configuring back camera only (ARKit handles front camera)")
        
        let session = AVCaptureSession()
        session.beginConfiguration()

        // セッションプリセットを設定
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        }

        // 背面カメラの設定のみ
        if let backCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back)
        {
            do {
                let backCameraInput = try AVCaptureDeviceInput(device: backCamera)
                if session.canAddInput(backCameraInput) {
                    session.addInput(backCameraInput)
                    self.backCameraDeviceInput = backCameraInput

                    // 背面カメラの出力設定（30fps維持のため最高優先度）
                    let backCameraOutput = AVCaptureVideoDataOutput()
                    backCameraOutput.setSampleBufferDelegate(
                        self, queue: DispatchQueue(label: "back.camera.output.queue", qos: .userInteractive))
                    backCameraOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    backCameraOutput.alwaysDiscardsLateVideoFrames = false  // フレーム破棄を無効化して30fps確保

                    if session.canAddOutput(backCameraOutput) {
                        session.addOutput(backCameraOutput)
                        self.backCameraVideoDataOutput = backCameraOutput

                        // 背面カメラの接続設定
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
                print("MultiCameraManager: Error setting up back camera: \(error)")
            }
        }

        session.commitConfiguration()
        
        // セッションを保存
        self.captureSession = session

        // 背面カメラのプレビューレイヤーのみ作成
        DispatchQueue.main.async {
            let backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            backPreviewLayer.videoGravity = .resizeAspectFill
            self.backCameraPreviewLayer = backPreviewLayer
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
                        self, queue: DispatchQueue(label: "back.camera.output.queue", qos: .userInteractive))
                    backCameraOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    backCameraOutput.alwaysDiscardsLateVideoFrames = false  // フレーム破棄を無効化して30fps確保

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

        // セッションを保存
        self.captureSession = session

        DispatchQueue.main.async {
            let backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            backPreviewLayer.videoGravity = .resizeAspectFill
            self.backCameraPreviewLayer = backPreviewLayer
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession, !session.isRunning else {
                return
            }

            print("MultiCameraManager: Starting capture session with high priority for 30fps")
            session.startRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = session.isRunning
                print("MultiCameraManager: Session running: \(self.isSessionRunning)")
                
                // 背面カメラが安定したことを通知
                if self.isSessionRunning {
                    print("MultiCameraManager: Back camera session established, ready for facial expression tracking")
                }
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.captureSession, session.isRunning else {
                return
            }

            print("MultiCameraManager: Stopping capture session")
            session.stopRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = false
                print("MultiCameraManager: Session stopped")
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

        // 背面カメラからの出力のみ
        if output == backCameraVideoDataOutput {
            delegate?.multiCameraManager(self, didOutputBackCamera: pixelBuffer)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        print("MultiCameraManager: Frame dropped from back camera")
    }
}
