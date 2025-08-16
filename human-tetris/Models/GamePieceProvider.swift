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
        let shapes: [[(x: Int, y: Int)]] = [
            // I型
            [(0, 0), (0, 1), (0, 2), (0, 3)],
            // L型
            [(0, 0), (0, 1), (0, 2), (1, 2)],
            // T型
            [(0, 1), (1, 0), (1, 1), (1, 2)],
            // Z型
            [(0, 0), (0, 1), (1, 1), (1, 2)],
            // O型
            [(0, 0), (0, 1), (1, 0), (1, 1)]
        ]
        
        let randomShape = shapes.randomElement() ?? shapes[0]
        return Polyomino(cells: randomShape)
    }
    
    var nextPiecePreview: Polyomino? {
        return nextPieces.first
    }
}