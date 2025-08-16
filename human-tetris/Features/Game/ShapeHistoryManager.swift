//
//  ShapeHistoryManager.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation

class ShapeHistoryManager: ObservableObject {
    @Published private(set) var recentShapes: [String] = [] // shapeId履歴
    
    private let maxHistorySize: Int = 3 // 直近3ピース
    
    // MARK: - Public Interface
    
    func addShape(_ polyomino: Polyomino) {
        let shapeId = polyomino.calculateShapeId()
        addShapeId(shapeId)
    }
    
    func addShapeId(_ shapeId: String) {
        recentShapes.append(shapeId)
        
        // 履歴サイズを制限
        if recentShapes.count > maxHistorySize {
            recentShapes.removeFirst()
        }
        
        print("ShapeHistoryManager: Added shape \(shapeId), recent shapes: \(recentShapes)")
    }
    
    func isShapeAllowed(_ polyomino: Polyomino) -> Bool {
        let shapeId = polyomino.calculateShapeId()
        return !recentShapes.contains(shapeId)
    }
    
    func isShapeIdAllowed(_ shapeId: String) -> Bool {
        return !recentShapes.contains(shapeId)
    }
    
    func clearHistory() {
        recentShapes.removeAll()
        print("ShapeHistoryManager: History cleared")
    }
    
    // MARK: - Validation Logic
    
    func validatePiece(_ polyomino: Polyomino) -> ValidationResult {
        // セル数チェック
        let cellCount = polyomino.cells.count
        if cellCount < 3 {
            return .failure(.tooFewCells(cellCount))
        }
        if cellCount > 6 {
            return .failure(.tooManyCells(cellCount))
        }
        
        // 同形チェック
        if !isShapeAllowed(polyomino) {
            return .failure(.duplicateShape(polyomino.calculateShapeId()))
        }
        
        return .success
    }
    
    // MARK: - Statistics
    
    var diversityScore: Double {
        let uniqueShapes = Set(recentShapes).count
        let totalShapes = recentShapes.count
        
        guard totalShapes > 0 else { return 1.0 }
        return Double(uniqueShapes) / Double(totalShapes)
    }
    
    var consecutiveDuplicates: Int {
        guard recentShapes.count >= 2 else { return 0 }
        
        let lastShape = recentShapes.last!
        var count = 0
        
        for shape in recentShapes.reversed() {
            if shape == lastShape {
                count += 1
            } else {
                break
            }
        }
        
        return count - 1 // 最後の1個は除外
    }
}

// MARK: - Validation Result

enum ValidationResult {
    case success
    case failure(ValidationError)
    
    var isValid: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error.localizedDescription
        }
    }
}

enum ValidationError: LocalizedError {
    case tooFewCells(Int)
    case tooManyCells(Int)
    case duplicateShape(String)
    case humanNotDetected
    case segmentationFailed
    
    var errorDescription: String? {
        switch self {
        case .tooFewCells(let count):
            return "セル数が不足（\(count) < 3）"
        case .tooManyCells(let count):
            return "セル数が多すぎ（\(count) > 6）"
        case .duplicateShape(let shapeId):
            return "直近のピースと同形（\(shapeId)）"
        case .humanNotDetected:
            return "人物が検出されませんでした"
        case .segmentationFailed:
            return "セグメンテーションに失敗しました"
        }
    }
}

// MARK: - Fallback Strategy

extension ShapeHistoryManager {
    func generateFallbackPiece() -> Polyomino {
        // 直近の形状を避けたフォールバック生成
        return StandardTetrominos.randomExcluding(shapeIds: recentShapes)
    }
    
    func shouldUseFallback(for error: ValidationError) -> Bool {
        switch error {
        case .tooFewCells, .tooManyCells, .duplicateShape:
            return true
        case .humanNotDetected, .segmentationFailed:
            return true
        }
    }
}