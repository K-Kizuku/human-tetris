//
//  GameState.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation

enum CellState: Equatable {
    case empty
    case filled(color: Int)
}

struct GameState {
    static let boardWidth = 10
    static let boardHeight = 20
    
    var board: [[CellState]]
    var currentPiece: Polyomino?
    var currentPosition: (x: Int, y: Int)
    var score: Int
    var linesCleared: Int
    var level: Int
    var gameOver: Bool
    
    init() {
        self.board = Array(repeating: Array(repeating: CellState.empty, count: GameState.boardWidth), count: GameState.boardHeight)
        self.currentPiece = nil
        self.currentPosition = (x: 0, y: 0)
        self.score = 0
        self.linesCleared = 0
        self.level = 1
        self.gameOver = false
    }
    
    func isValidPosition(piece: Polyomino, at position: (x: Int, y: Int)) -> Bool {
        for cell in piece.cells {
            let boardX = position.x + cell.x
            let boardY = position.y + cell.y
            
            if boardX < 0 || boardX >= GameState.boardWidth ||
               boardY < 0 || boardY >= GameState.boardHeight {
                return false
            }
            
            if case .filled = board[boardY][boardX] {
                return false
            }
        }
        
        return true
    }
    
    mutating func placePiece(piece: Polyomino, at position: (x: Int, y: Int), color: Int = 1) {
        for cell in piece.cells {
            let boardX = position.x + cell.x
            let boardY = position.y + cell.y
            
            if boardX >= 0 && boardX < GameState.boardWidth &&
               boardY >= 0 && boardY < GameState.boardHeight {
                board[boardY][boardX] = .filled(color: color)
            }
        }
    }
    
    mutating func clearLines() -> Int {
        var linesCleared = 0
        var newBoard: [[CellState]] = []
        
        for row in board.reversed() {
            if !row.allSatisfy({ if case .filled = $0 { return true } else { return false } }) {
                newBoard.append(row)
            } else {
                linesCleared += 1
            }
        }
        
        while newBoard.count < GameState.boardHeight {
            newBoard.append(Array(repeating: CellState.empty, count: GameState.boardWidth))
        }
        
        board = newBoard.reversed()
        self.linesCleared += linesCleared
        
        return linesCleared
    }
    
    func getColumnHeights() -> [Int] {
        var heights = Array(repeating: 0, count: GameState.boardWidth)
        
        for col in 0..<GameState.boardWidth {
            for row in 0..<GameState.boardHeight {
                if case .filled = board[row][col] {
                    heights[col] = GameState.boardHeight - row
                    break
                }
            }
        }
        
        return heights
    }
    
    func getHoles() -> Int {
        var holes = 0
        
        for col in 0..<GameState.boardWidth {
            var foundFilled = false
            for row in 0..<GameState.boardHeight {
                if case .filled = board[row][col] {
                    foundFilled = true
                } else if foundFilled {
                    holes += 1
                }
            }
        }
        
        return holes
    }
}

struct CaptureState {
    var grid: Grid4x3
    var iou: Float
    var stableMs: Int
    var isStable: Bool {
        return stableMs >= 400
    }
    
    init() {
        self.grid = Grid4x3()
        self.iou = 0.0
        self.stableMs = 0
    }
}