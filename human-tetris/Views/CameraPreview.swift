//
//  CameraPreview.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            previewLayer.frame = uiView.bounds
        }
    }
}

struct Grid4x3Overlay: View {
    let roiFrame: CGRect
    @State private var animationPhase: Double = 0
    
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.blue.opacity(0.7), lineWidth: 2)
                .frame(width: roiFrame.width, height: roiFrame.height)
                .position(x: roiFrame.midX, y: roiFrame.midY)
                .scaleEffect(1.0 + sin(animationPhase) * 0.05)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever()) {
                        animationPhase = .pi * 2
                    }
                }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 1) {
                ForEach(0..<12, id: \.self) { index in
                    Rectangle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        .frame(width: roiFrame.width / 3, height: roiFrame.height / 4)
                }
            }
            .frame(width: roiFrame.width, height: roiFrame.height)
            .position(x: roiFrame.midX, y: roiFrame.midY)
        }
    }
}

struct OccupancyHeatmap: View {
    let grid: Grid4x3
    let roiFrame: CGRect
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 1) {
            ForEach(0..<12, id: \.self) { index in
                let row = index / 3
                let col = index % 3
                let isOn = grid.on[row][col]
                Rectangle()
                    .fill(isOn ? Color.green.opacity(0.6) : Color.clear)
                    .frame(width: roiFrame.width / 3, height: roiFrame.height / 4)
                    .animation(.easeInOut(duration: 0.1), value: isOn)
            }
        }
        .frame(width: roiFrame.width, height: roiFrame.height)
        .position(x: roiFrame.midX, y: roiFrame.midY)
    }
}