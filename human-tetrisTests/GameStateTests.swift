//
//  GameStateTests.swift
//  human-tetrisTests
//
//  Created by Claude Code on 2025/08/17.
//

import Testing
@testable import human_tetris

struct GameStateTests {
    
    @Test func testInitialGameState() {
        let gameState = GameState()
        
        #expect(gameState.score == 0)
        #expect(gameState.linesCleared == 0)
        #expect(gameState.level == 1)
        #expect(gameState.gameOver == false)
        #expect(gameState.currentPiece == nil)
    }
    
    @Test func testGameOverDetection() {
        var gameState = GameState()
        
        // 最上部の行（y=0）にピースを配置
        gameState.board[0][5] = .filled(color: 1)
        
        // ゲームオーバー条件をチェック
        #expect(gameState.checkGameOver() == true)
    }
    
    @Test func testGameOverNotDetected() {
        var gameState = GameState()
        
        // 最上部の行以外にピースを配置
        gameState.board[1][5] = .filled(color: 1)
        gameState.board[10][3] = .filled(color: 1)
        
        // ゲームオーバー条件をチェック（最上部は空なのでfalse）
        #expect(gameState.checkGameOver() == false)
    }
    
    @Test func testGameOverAfterPiecePlacement() {
        var gameState = GameState()
        
        // 最上部近くまでブロックを積み上げる
        for x in 0..<GameState.boardWidth {
            for y in 1..<GameState.boardHeight {
                gameState.board[y][x] = .filled(color: 1)
            }
        }
        
        // 小さなピースを配置（最上部に到達するはず）
        let piece = Polyomino(cells: [(x: 0, y: 0)])
        gameState.placePiece(piece: piece, at: (x: 0, y: 0))
        
        // ゲームオーバーになっているはず
        #expect(gameState.gameOver == true)
    }
    
    @Test func testValidPieceSpawn() {
        let gameState = GameState()
        let piece = Polyomino(cells: [(x: 0, y: 0), (x: 1, y: 0)])
        
        // 空の盤面では正常にスポーンできるはず
        #expect(gameState.canSpawnPiece(piece, at: (x: 0, y: 0)) == true)
        #expect(gameState.canSpawnPiece(piece, at: (x: 5, y: 0)) == true)
    }
    
    @Test func testInvalidPieceSpawn() {
        var gameState = GameState()
        
        // 最上部にブロックを配置
        gameState.board[0][0] = .filled(color: 1)
        
        let piece = Polyomino(cells: [(x: 0, y: 0), (x: 1, y: 0)])
        
        // ブロックがある場所にはスポーンできないはず
        #expect(gameState.canSpawnPiece(piece, at: (x: 0, y: 0)) == false)
        
        // 他の場所は大丈夫
        #expect(gameState.canSpawnPiece(piece, at: (x: 2, y: 0)) == true)
    }
}