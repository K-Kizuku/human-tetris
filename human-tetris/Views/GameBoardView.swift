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
                    cellSize: cellSize
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
    
    var body: some View {
        ForEach(Array(piece.cells.enumerated()), id: \.offset) { index, cell in
            let x = position.x + cell.x
            let y = position.y + cell.y
            
            if x >= 0 && x < GameState.boardWidth &&
               y >= 0 && y < GameState.boardHeight {
                CellView(
                    state: .filled(color: 2),
                    cellSize: cellSize,
                    animated: false
                )
                .position(
                    x: CGFloat(x) * cellSize + cellSize / 2,
                    y: CGFloat(y) * cellSize + cellSize / 2
                )
                .animation(
                    .easeInOut(duration: 0.1),
                    value: "\(position.x),\(position.y)"
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
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: cellSize, height: cellSize)
                }
            }
        }
        .scaleEffect(animated ? 1.0 : 0.9)
        .animation(
            animated ? .spring(response: 0.3, dampingFraction: 0.8) : nil,
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

#Preview {
    GameBoardView(gameCore: GameCore())
        .padding()
        .background(Color.black)
}