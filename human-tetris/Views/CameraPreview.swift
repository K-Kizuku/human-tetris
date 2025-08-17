//
//  CameraPreview.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import AVFoundation
import SwiftUI
import UIKit

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

struct Grid4x3Overlay: View {
    let cameraWidth: CGFloat
    let cameraHeight: CGFloat
    var gridResult: PieceGenerationResult? = nil

    var body: some View {
        ZStack {
            // カメラ全体の境界線（マス数に応じた色）
            Rectangle()
                .stroke(getBorderColor(), lineWidth: 3)
                .frame(width: cameraWidth, height: cameraHeight)

            // 4x3グリッド線（一本線で描画）
            GridLinesView(
                columns: 3,
                rows: 4,
                width: cameraWidth,
                height: cameraHeight,
                lineColor: Color.white.opacity(0.7),
                lineWidth: 1.5
            )
        }
    }
    
    private func getBorderColor() -> Color {
        guard let result = gridResult else {
            return Color.blue.opacity(0.8)
        }
        
        switch result {
        case .valid:
            return Color.blue.opacity(0.8)
        case .tooFew:
            return Color.red.opacity(0.8)
        case .tooMany:
            return Color.orange.opacity(0.8)
        }
    }
}

// 共通のグリッド線描画View
struct GridLinesView: View {
    let columns: Int
    let rows: Int
    let width: CGFloat
    let height: CGFloat
    let lineColor: Color
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            // 縦線
            ForEach(1..<columns, id: \.self) { col in
                Rectangle()
                    .fill(lineColor)
                    .frame(width: lineWidth, height: height)
                    .position(
                        x: CGFloat(col) * (width / CGFloat(columns)),
                        y: height / 2
                    )
            }
            
            // 横線
            ForEach(1..<rows, id: \.self) { row in
                Rectangle()
                    .fill(lineColor)
                    .frame(width: width, height: lineWidth)
                    .position(
                        x: width / 2,
                        y: CGFloat(row) * (height / CGFloat(rows))
                    )
            }
        }
        .frame(width: width, height: height)
    }
}

struct OccupancyHeatmap: View {
    let grid: Grid4x3
    let cameraWidth: CGFloat
    let cameraHeight: CGFloat
    var occupancyRates: [[Float]]? = nil
    var showOccupancyText: Bool = false

    var body: some View {
        ZStack {
            // セル背景（枠線なし）
            ForEach(0..<4, id: \.self) { row in
                ForEach(0..<3, id: \.self) { col in
                    let isOn = grid.on[row][col]
                    let occupancyRate = occupancyRates?[row][col] ?? 0.0
                    
                    ZStack {
                        Rectangle()
                            .fill(getCellColor(isOn: isOn, occupancyRate: occupancyRate, gridResult: grid.pieceGenerationResult))
                            .animation(.easeInOut(duration: 0.2), value: isOn)
                        
                        // デバッグ用占有率テキスト
                        if showOccupancyText && occupancyRate > 0.1 {
                            Text("\(Int(occupancyRate * 100))")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(
                        width: cameraWidth / 3,
                        height: cameraHeight / 4
                    )
                    .position(
                        x: (CGFloat(col) + 0.5) * (cameraWidth / 3),
                        y: (CGFloat(row) + 0.5) * (cameraHeight / 4)
                    )
                }
            }
        }
        .frame(width: cameraWidth, height: cameraHeight)
        .clipped()
    }
    
    private func getCellColor(isOn: Bool, occupancyRate: Float, gridResult: PieceGenerationResult) -> Color {
        if isOn {
            // ONの場合：ピース生成結果に応じて色分け
            let opacity = max(0.5, min(0.9, Double(occupancyRate)))
            
            switch gridResult {
            case .valid:
                // 有効範囲：緑色
                return Color.green.opacity(opacity)
            case .tooFew:
                // マス不足：赤色
                return Color.red.opacity(opacity)
            case .tooMany:
                // マス過多：オレンジ色
                return Color.orange.opacity(opacity)
            }
        } else {
            // OFFの場合：ピース生成結果に応じて薄い色で表示
            if occupancyRate > 0.15 {
                switch gridResult {
                case .valid:
                    return Color.yellow.opacity(Double(occupancyRate) * 0.3)
                case .tooFew:
                    return Color.red.opacity(Double(occupancyRate) * 0.2)
                case .tooMany:
                    return Color.orange.opacity(Double(occupancyRate) * 0.2)
                }
            } else {
                return Color.clear
            }
        }
    }
}
