//
//  GamePieceProvider.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation

protocol GamePieceProvider {
    func requestNextPiece(completion: @escaping (Polyomino?) -> Void)
    func isAvailable() -> Bool
    
    // 新機能: 3秒カウントダウン制御
    func beginCountdown()              // 3秒開始
    func cancelCountdown()
    func captureAtZero() -> Polyomino? // 0秒スナップショット→成功なら形状、失敗ならnil
    func fallbackTetromino() -> Polyomino // 7種から等確率
}

// ピースキューシステム
class PieceQueue: ObservableObject {
    @Published private(set) var nextPieces: [Polyomino] = []
    @Published private(set) var isWaitingForPiece = false
    
    private let maxQueueSize = 3
    private var provider: GamePieceProvider?
    
    func setProvider(_ provider: GamePieceProvider) {
        self.provider = provider
    }
    
    func getNextPiece(completion: @escaping (Polyomino?) -> Void) {
        if !nextPieces.isEmpty {
            let piece = nextPieces.removeFirst()
            completion(piece)
            fillQueue()
        } else {
            isWaitingForPiece = true
            requestPieceFromProvider { [weak self] piece in
                DispatchQueue.main.async {
                    self?.isWaitingForPiece = false
                    completion(piece)
                    self?.fillQueue()
                }
            }
        }
    }
    
    func preloadPieces() {
        // 非同期でキューを埋める
        DispatchQueue.global(qos: .userInitiated).async {
            self.fillQueueAsync()
        }
    }
    
    private func fillQueue() {
        // 非同期版を呼び出し
        DispatchQueue.global(qos: .userInitiated).async {
            self.fillQueueAsync()
        }
    }
    
    private func fillQueueAsync() {
        let neededPieces = maxQueueSize - nextPieces.count
        guard neededPieces > 0 else { return }
        
        let group = DispatchGroup()
        
        for _ in 0..<neededPieces {
            group.enter()
            requestPieceFromProvider { [weak self] piece in
                defer { group.leave() }
                DispatchQueue.main.async {
                    if let piece = piece {
                        self?.nextPieces.append(piece)
                    }
                }
            }
        }
    }
    
    private func requestPieceFromProvider(completion: @escaping (Polyomino?) -> Void) {
        guard let provider = provider, provider.isAvailable() else {
            // フォールバック: ランダムピース生成
            completion(generateFallbackPiece())
            return
        }
        
        provider.requestNextPiece(completion: completion)
    }
    
    private func generateFallbackPiece() -> Polyomino {
        return StandardTetrominos.random()
    }
}

// MARK: - Standard Tetrominos (7種類)

struct StandardTetrominos {
    static let allShapes: [Polyomino] = [
        // I型 (4セル, 直線)
        Polyomino(cells: [(0, 0), (0, 1), (0, 2), (0, 3)]),
        
        // O型 (4セル, 正方形)
        Polyomino(cells: [(0, 0), (0, 1), (1, 0), (1, 1)]),
        
        // T型 (4セル, T字)
        Polyomino(cells: [(0, 1), (1, 0), (1, 1), (1, 2)]),
        
        // L型 (4セル, L字)
        Polyomino(cells: [(0, 0), (0, 1), (0, 2), (1, 2)]),
        
        // J型 (4セル, 逆L字)
        Polyomino(cells: [(0, 2), (1, 0), (1, 1), (1, 2)]),
        
        // S型 (4セル, S字)
        Polyomino(cells: [(0, 1), (0, 2), (1, 0), (1, 1)]),
        
        // Z型 (4セル, Z字)
        Polyomino(cells: [(0, 0), (0, 1), (1, 1), (1, 2)])
    ]
    
    static func random() -> Polyomino {
        return allShapes.randomElement() ?? allShapes[0]
    }
    
    static func randomExcluding(shapeIds: [String]) -> Polyomino {
        let availableShapes = allShapes.filter { piece in
            !shapeIds.contains(piece.calculateShapeId())
        }
        return availableShapes.randomElement() ?? random()
    }
}

// MARK: - PieceQueue Extensions

extension PieceQueue {
    var nextPiecePreview: Polyomino? {
        return nextPieces.first
    }
}