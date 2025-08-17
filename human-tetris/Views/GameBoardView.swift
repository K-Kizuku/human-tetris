//
//  GameBoardView.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import SwiftUI

struct GameBoardView: View {
    @ObservedObject var gameCore: GameCore
    let targetSize: CGSize
    
    // アニメーション状態
    @State private var animationPhase: Double = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var scaleEffect: CGFloat = 1.0
    @State private var boardGlow: Bool = false
    @State private var pieceDropAnimation: Bool = false
    
    init(gameCore: GameCore, targetSize: CGSize = CGSize(width: 250, height: 500)) {
        self.gameCore = gameCore
        self.targetSize = targetSize
    }
    
    private var cellSize: CGFloat {
        let widthBasedSize = (targetSize.width - borderWidth) / CGFloat(GameState.boardWidth)
        let heightBasedSize = (targetSize.height - borderWidth) / CGFloat(GameState.boardHeight)
        return min(widthBasedSize, heightBasedSize, 30) // 最大30ptに制限
    }
    
    private let borderWidth: CGFloat = 1
    
    var body: some View {
        ZStack {
            // 背景グリッド
            BackgroundGrid(
                width: GameState.boardWidth,
                height: GameState.boardHeight,
                cellSize: cellSize,
                borderWidth: borderWidth
            )
            
            // 配置済みピース
            PlacedPiecesView(
                board: gameCore.gameState.board,
                cellSize: cellSize
            )
            
            // ゴーストピース
            if let ghostPosition = gameCore.getGhostPosition(),
               let currentPiece = gameCore.gameState.currentPiece {
                GhostPieceView(
                    piece: currentPiece,
                    position: ghostPosition,
                    cellSize: cellSize
                )
            }
            
            // 現在のピース
            if let currentPiece = gameCore.gameState.currentPiece {
                CurrentPieceView(
                    piece: currentPiece,
                    position: gameCore.gameState.currentPosition,
                    cellSize: cellSize,
                    isDropping: pieceDropAnimation
                )
            }
        }
        .frame(
            width: CGFloat(GameState.boardWidth) * cellSize + borderWidth,
            height: CGFloat(GameState.boardHeight) * cellSize + borderWidth
        )
        .background(Color.black.opacity(0.8))
        .border(Color.white.opacity(0.5), width: 2)
        .cornerRadius(4)
        .offset(x: shakeOffset)
        .scaleEffect(scaleEffect)
        .shadow(color: boardGlow ? .cyan.opacity(0.6) : .clear, radius: boardGlow ? 8 : 0)
        .animation(.easeInOut(duration: 0.3), value: boardGlow)
        .onReceive(gameCore.$isAnimating) { isAnimating in
            if isAnimating {
                triggerLineClearAnimation()
            }
        }
        .onChange(of: gameCore.gameState.linesCleared) { _, newLines in
            if newLines > 0 {
                triggerScoreAnimation()
                // ボードグローエフェクト
                boardGlow = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    boardGlow = false
                }
            }
        }
        .onChange(of: gameCore.gameState.currentPiece) { oldPiece, newPiece in
            if oldPiece != nil && newPiece != nil {
                // 新しいピースがスポーンした時のアニメーション
                triggerPieceSpawnAnimation()
            }
        }
    }
}

struct BackgroundGrid: View {
    let width: Int
    let height: Int
    let cellSize: CGFloat
    let borderWidth: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<height, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<width, id: \.self) { col in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: cellSize, height: cellSize)
                            .border(
                                Color.white.opacity(0.1),
                                width: borderWidth
                            )
                    }
                }
            }
        }
    }
}

struct PlacedPiecesView: View {
    let board: [[CellState]]
    let cellSize: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(board.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        CellView(
                            state: cell,
                            cellSize: cellSize,
                            animated: true
                        )
                    }
                }
            }
        }
    }
}

struct CurrentPieceView: View {
    let piece: Polyomino
    let position: (x: Int, y: Int)
    let cellSize: CGFloat
    let isDropping: Bool
    
    init(piece: Polyomino, position: (x: Int, y: Int), cellSize: CGFloat, isDropping: Bool = false) {
        self.piece = piece
        self.position = position
        self.cellSize = cellSize
        self.isDropping = isDropping
    }
    
    var body: some View {
        ForEach(Array(piece.cells.enumerated()), id: \.offset) { index, cell in
            let x = position.x + cell.x
            let y = position.y + cell.y
            
            if x >= 0 && x < GameState.boardWidth &&
               y >= 0 && y < GameState.boardHeight {
                CellView(
                    state: .filled(color: 2),
                    cellSize: cellSize,
                    animated: true
                )
                .position(
                    x: CGFloat(x) * cellSize + cellSize / 2,
                    y: CGFloat(y) * cellSize + cellSize / 2
                )
                .scaleEffect(isDropping ? 1.1 : 1.0)
                .shadow(color: .cyan.opacity(0.6), radius: isDropping ? 4 : 0)
                .animation(
                    .easeInOut(duration: 0.15),
                    value: "\(position.x),\(position.y)"
                )
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.7),
                    value: isDropping
                )
            }
        }
    }
}

struct GhostPieceView: View {
    let piece: Polyomino
    let position: (x: Int, y: Int)
    let cellSize: CGFloat
    
    var body: some View {
        ForEach(Array(piece.cells.enumerated()), id: \.offset) { index, cell in
            let x = position.x + cell.x
            let y = position.y + cell.y
            
            if x >= 0 && x < GameState.boardWidth &&
               y >= 0 && y < GameState.boardHeight {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: cellSize, height: cellSize)
                    .border(Color.white.opacity(0.5), width: 1)
                    .position(
                        x: CGFloat(x) * cellSize + cellSize / 2,
                        y: CGFloat(y) * cellSize + cellSize / 2
                    )
            }
        }
    }
}

struct CellView: View {
    let state: CellState
    let cellSize: CGFloat
    let animated: Bool
    
    @State private var shimmerOffset: CGFloat = -1.0
    
    var body: some View {
        Group {
            switch state {
            case .empty:
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: cellSize, height: cellSize)
                
            case .filled(let color):
                ZStack {
                    Rectangle()
                        .fill(colorForPiece(color))
                        .frame(width: cellSize, height: cellSize)
                    
                    Rectangle()
                        .stroke(
                            colorForPiece(color).opacity(0.8),
                            lineWidth: 1
                        )
                        .frame(width: cellSize, height: cellSize)
                    
                    // シマーエフェクトを追加
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ]),
                                startPoint: UnitPoint(x: shimmerOffset, y: 0),
                                endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 1)
                            )
                        )
                        .frame(width: cellSize, height: cellSize)
                        .onAppear {
                            if animated {
                                withAnimation(
                                    .linear(duration: 2.0).repeatForever(autoreverses: false)
                                ) {
                                    shimmerOffset = 1.3
                                }
                            }
                        }
                }
            }
        }
        .scaleEffect(animated ? 1.0 : 0.95)
        .opacity(animated ? 1.0 : 0.9)
        .animation(
            animated ? .spring(response: 0.4, dampingFraction: 0.7) : .easeInOut(duration: 0.2),
            value: state
        )
    }
    
    private func colorForPiece(_ colorIndex: Int) -> Color {
        let colors: [Color] = [
            .clear,      // 0: empty
            .red,        // 1: placed piece
            .cyan,       // 2: current piece
            .green,      // 3: special
            .orange,     // 4: special
            .purple,     // 5: special
            .yellow      // 6: special
        ]
        
        return colors[min(colorIndex, colors.count - 1)]
    }
}

// MARK: - GameBoardView Animation Extensions

extension GameBoardView {
    private func triggerLineClearAnimation() {
        // ライン消去時のシェイクアニメーション
        withAnimation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)) {
            shakeOffset = 5
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shakeOffset = 0
        }
    }
    
    private func triggerScoreAnimation() {
        // スコア獲得時のスケールアニメーション
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scaleEffect = 1.05
        }
        
        withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
            scaleEffect = 1.0
        }
    }
    
    private func triggerPieceSpawnAnimation() {
        // 新しいピーススポーン時のアニメーション
        withAnimation(.easeOut(duration: 0.2)) {
            pieceDropAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pieceDropAnimation = false
        }
    }
}

#Preview {
    GameBoardView(gameCore: GameCore())
        .padding()
        .background(Color.black)
}