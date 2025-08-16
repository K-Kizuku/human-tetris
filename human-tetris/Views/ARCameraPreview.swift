//
//  ARCameraPreview.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI
import UIKit
import CoreVideo
import VideoToolbox
import CoreImage

struct ARCameraPreview: UIViewRepresentable {
    @Binding var pixelBuffer: CVPixelBuffer?
    
    func makeUIView(context: Context) -> ARCameraDisplayView {
        let view = ARCameraDisplayView()
        return view
    }
    
    func updateUIView(_ uiView: ARCameraDisplayView, context: Context) {
        if let buffer = pixelBuffer {
            uiView.displayPixelBuffer(buffer)
        }
    }
}

class ARCameraDisplayView: UIView {
    private var displayLayer: CALayer?
    private let ciContext = CIContext()
    private var currentPixelBuffer: CVPixelBuffer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupDisplayLayer()
        setupOrientationObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDisplayLayer()
        setupOrientationObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupDisplayLayer() {
        backgroundColor = UIColor.black
        
        let layer = CALayer()
        layer.contentsGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        displayLayer = layer
    }
    
    private func setupOrientationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        // デバイスの向き通知を有効にする
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }
    
    @objc private func orientationDidChange() {
        let orientation = getDeviceOrientation()
        print("ARCameraPreview: Device orientation changed to: \(orientation.rawValue)")
        
        // 向きが変更されたら現在のフレームを再描画
        if let buffer = currentPixelBuffer {
            displayPixelBuffer(buffer)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer?.frame = bounds
    }
    
    private func getDeviceOrientation() -> UIDeviceOrientation {
        return UIDevice.current.orientation
    }
    
    private func getRotationAngleForOrientation() -> CGFloat {
        // ARSessionからのフレームを正しい向きに調整
        // 180度回転している問題を修正するため、回転角度を反転
        
        let orientation = getDeviceOrientation()
        
        switch orientation {
        case .portrait:
            return -90.0 * .pi / 180.0  // -90度（反時計回り）でポートレート表示
        case .portraitUpsideDown:
            return 90.0 * .pi / 180.0   // 90度回転
        case .landscapeLeft:
            return 0.0  // 回転なし
        case .landscapeRight:
            return 180.0 * .pi / 180.0  // 180度回転
        case .unknown, .faceUp, .faceDown:
            // 不明な向きの場合はポートレート向けとして扱う
            return -90.0 * .pi / 180.0
        @unknown default:
            return -90.0 * .pi / 180.0
        }
    }
    
    func displayPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        // 現在のフレームを保存（向き変更時の再描画用）
        currentPixelBuffer = pixelBuffer
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // CVPixelBufferからCIImageを作成
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // デバイスの向きに応じて回転角度を取得
            let rotationAngle = self.getRotationAngleForOrientation()
            let rotationDegrees = rotationAngle * 180.0 / .pi
            
            // 回転変換を適用（中央を基準点として回転）
            let imageCenter = CGPoint(x: ciImage.extent.midX, y: ciImage.extent.midY)
            
            print("ARCameraPreview: Applying rotation: \(rotationDegrees) degrees for orientation: \(self.getDeviceOrientation().rawValue)")
            print("ARCameraPreview: Original image extent: \(ciImage.extent)")
            print("ARCameraPreview: Image center: \(imageCenter)")
            let transform = CGAffineTransform(translationX: imageCenter.x, y: imageCenter.y)
                .rotated(by: rotationAngle)
                .translatedBy(x: -imageCenter.x, y: -imageCenter.y)
            
            let rotatedImage = ciImage.transformed(by: transform)
            
            // CIImageからCGImageを作成
            guard let cgImage = self.ciContext.createCGImage(rotatedImage, from: rotatedImage.extent) else {
                print("ARCameraPreview: Failed to create CGImage from rotated CIImage")
                return
            }
            
            // レイヤーに画像を設定
            self.displayLayer?.contents = cgImage
        }
    }
}