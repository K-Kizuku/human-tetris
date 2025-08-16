//
//  CameraPreviewView.swift
//  human-tetris
//
//  Created by Kiro on 2025/08/17.
//

import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black

        DispatchQueue.main.async {
            if let previewLayer = cameraManager.previewLayer {
                previewLayer.frame = view.bounds
                previewLayer.videoGravity = .resizeAspectFill
                view.layer.addSublayer(previewLayer)
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = cameraManager.previewLayer {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}

#Preview {
    CameraPreviewView(cameraManager: CameraManager())
        .frame(width: 200, height: 150)
}
