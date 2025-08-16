//
//  CameraPreview.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import AVFoundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(UIKit)
    struct CameraPreview: UIViewRepresentable {
        let previewLayer: AVCaptureVideoPreviewLayer

        func makeUIView(context: Context) -> UIView {
            let view = UIView()
            view.backgroundColor = UIColor.black
            view.clipsToBounds = true

            // フルスクリーン映像を縮小して表示するためのビデオグラビティを設定
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            return view
        }

        func updateUIView(_ uiView: UIView, context: Context) {
            // プレビューレイヤーのフレームを即座に更新
            previewLayer.frame = uiView.bounds

            // フルスクリーン映像を適切に縮小表示
            previewLayer.videoGravity = .resizeAspectFill

            // レイアウトが完了した後に再度確認
            DispatchQueue.main.async {
                if self.previewLayer.frame != uiView.bounds {
                    self.previewLayer.frame = uiView.bounds
                }
            }
        }
    }
#else
    // UIKitが利用できない場合のフォールバック
    struct CameraPreview: View {
        let previewLayer: AVCaptureVideoPreviewLayer?

        var body: some View {
            Rectangle()
                .fill(Color.black)
                .overlay(
                    Text("カメラプレビュー未対応")
                        .foregroundColor(.white)
                )
        }
    }
#endif

struct Grid4x3Overlay: View {
    let cameraWidth: CGFloat
    let cameraHeight: CGFloat

    var body: some View {
        ZStack {
            // カメラ全体の境界線
            Rectangle()
                .stroke(Color.blue.opacity(0.7), lineWidth: 2)
                .frame(width: cameraWidth, height: cameraHeight)

            // 4x3グリッド（3列4行）
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 1) {
                ForEach(0..<12, id: \.self) { index in
                    Rectangle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
                        .frame(width: cameraWidth / 3, height: cameraHeight / 4)
                }
            }
            .frame(width: cameraWidth, height: cameraHeight)
        }
    }
}

struct OccupancyHeatmap: View {
    let grid: Grid4x3
    let cameraWidth: CGFloat
    let cameraHeight: CGFloat

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 1) {
            ForEach(0..<12, id: \.self) { index in
                let row = index / 3
                let col = index % 3
                let isOn = grid.on[row][col]
                let occupancyRate = grid.occupancyRate(at: row, col: col)

                Rectangle()
                    .fill(
                        isOn
                            ? Color.green.opacity(Double(occupancyRate) * 0.8)
                            : Color.clear
                    )
                    .frame(width: cameraWidth / 3, height: cameraHeight / 4)
                    .animation(.easeInOut(duration: 0.1), value: isOn)
            }
        }
        .frame(width: cameraWidth, height: cameraHeight)
    }
}
