//
//  Polyomino.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation

struct Polyomino: Equatable {
    let cells: [(x: Int, y: Int)]
    let rot: Int
    
    var size: Int { cells.count }
    
    static func == (lhs: Polyomino, rhs: Polyomino) -> Bool {
        return lhs.rot == rhs.rot && lhs.cells.count == rhs.cells.count &&
               lhs.cells.allSatisfy { lhsCell in
                   rhs.cells.contains { rhsCell in
                       lhsCell.x == rhsCell.x && lhsCell.y == rhsCell.y
                   }
               }
    }
    
    init(cells: [(x: Int, y: Int)], rot: Int = 0) {
        precondition(cells.count >= 3 && cells.count <= 6, "Polyomino must have 3-6 cells")
        self.cells = cells
        self.rot = rot % 4
    }
    
    var bounds: (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        guard !cells.isEmpty else { return (0, 0, 0, 0) }
        
        let xs = cells.map { $0.x }
        let ys = cells.map { $0.y }
        
        return (
            minX: xs.min()!,
            maxX: xs.max()!,
            minY: ys.min()!,
            maxY: ys.max()!
        )
    }
    
    var width: Int {
        let bounds = self.bounds
        return bounds.maxX - bounds.minX + 1
    }
    
    var height: Int {
        let bounds = self.bounds
        return bounds.maxY - bounds.minY + 1
    }
    
    var aspectRatio: Double {
        let w = Double(width)
        let h = Double(height)
        return max(w, h) / min(w, h)
    }
    
    var isSlender: Bool {
        return aspectRatio >= 2.0
    }
    
    var isWide: Bool {
        return aspectRatio <= 1.2
    }
    
    var isBalanced: Bool {
        return aspectRatio > 1.2 && aspectRatio < 2.0
    }
    
    func rotated() -> Polyomino {
        // 改良された回転アルゴリズム：
        // 1. 原点中心で回転
        // 2. バウンディングボックスが最小になるよう調整
        
        let rotatedCells = cells.map { cell in
            // 原点中心での90度時計回り回転: (x,y) -> (-y,x)
            return (x: -cell.y, y: cell.x)
        }
        
        // 正規化して重複を除去
        let normalizedCells = normalize(rotatedCells)
        let uniqueCells = removeDuplicateCells(normalizedCells)
        
        // セル数が保持されているかチェック
        if uniqueCells.count != cells.count {
            print("Warning: Cell count changed during rotation. Original: \(cells.count), New: \(uniqueCells.count)")
            // 元のセル数を保持するためのフォールバック処理
            return rotateWithCompactness()
        }
        
        return Polyomino(cells: uniqueCells, rot: rot + 1)
    }
    
    // より堅牢な回転アルゴリズム（フォールバック用）
    private func rotateWithCompactness() -> Polyomino {
        // セルを格子上で確実に回転させる
        var rotatedCells: [(x: Int, y: Int)] = []
        
        for cell in cells {
            let newX = -cell.y
            let newY = cell.x
            rotatedCells.append((x: newX, y: newY))
        }
        
        // 正規化（最小座標を0,0に）
        let normalizedCells = normalize(rotatedCells)
        
        // セルの数が合わない場合の検証
        if normalizedCells.count != cells.count {
            print("Error: Rotation failed to preserve cell count")
            return self // 回転失敗時は元のピースを返す
        }
        
        return Polyomino(cells: normalizedCells, rot: rot + 1)
    }
    
    func translated(dx: Int, dy: Int) -> Polyomino {
        let translatedCells = cells.map { (x: $0.x + dx, y: $0.y + dy) }
        return Polyomino(cells: translatedCells, rot: rot)
    }
    
    private var centroid: (x: Double, y: Double) {
        let sumX = cells.reduce(0) { $0 + $1.x }
        let sumY = cells.reduce(0) { $0 + $1.y }
        return (
            x: Double(sumX) / Double(cells.count),
            y: Double(sumY) / Double(cells.count)
        )
    }
    
    private func normalize(_ cells: [(x: Int, y: Int)]) -> [(x: Int, y: Int)] {
        guard !cells.isEmpty else { return cells }
        
        let minX = cells.map { $0.x }.min()!
        let minY = cells.map { $0.y }.min()!
        
        return cells.map { (x: $0.x - minX, y: $0.y - minY) }
    }
    
    private func removeDuplicateCells(_ cells: [(x: Int, y: Int)]) -> [(x: Int, y: Int)] {
        var uniqueCells: [(x: Int, y: Int)] = []
        var seen: Set<String> = []
        
        for cell in cells {
            let key = "\(cell.x),\(cell.y)"
            if !seen.contains(key) {
                seen.insert(key)
                uniqueCells.append(cell)
            }
        }
        
        return uniqueCells
    }
    
    // MARK: - Shape Signature (shapeId) for equivalence detection
    
    func calculateShapeId() -> String {
        // 回転・反転を含めた形状の正規化署名を計算
        let normalizedCells = normalize(cells)
        
        // 全ての回転（0, 90, 180, 270度）と反転の組み合わせを生成
        var allVariants: [[(x: Int, y: Int)]] = []
        
        // 4つの回転
        var currentVariant = normalizedCells
        for _ in 0..<4 {
            allVariants.append(normalize(currentVariant))
            currentVariant = rotateVariant(currentVariant)
        }
        
        // 水平反転後の4つの回転
        let flippedVariant = flipHorizontally(normalizedCells)
        currentVariant = flippedVariant
        for _ in 0..<4 {
            allVariants.append(normalize(currentVariant))
            currentVariant = rotateVariant(currentVariant)
        }
        
        // 全てのバリアントを辞書順でソートし、最小のものを正規形とする
        let sortedVariants = allVariants.map { variantToString($0) }.sorted()
        return sortedVariants.first ?? ""
    }
    
    private func rotateVariant(_ cells: [(x: Int, y: Int)]) -> [(x: Int, y: Int)] {
        // 90度時計回り回転: (x,y) -> (-y,x)
        return cells.map { (x: -$0.y, y: $0.x) }
    }
    
    private func flipHorizontally(_ cells: [(x: Int, y: Int)]) -> [(x: Int, y: Int)] {
        guard !cells.isEmpty else { return cells }
        let maxX = cells.map { $0.x }.max()!
        return cells.map { (x: maxX - $0.x, y: $0.y) }
    }
    
    private func variantToString(_ cells: [(x: Int, y: Int)]) -> String {
        let sortedCells = cells.sorted { (a, b) in
            if a.x != b.x { return a.x < b.x }
            return a.y < b.y
        }
        return sortedCells.map { "\($0.x),\($0.y)" }.joined(separator: ";")
    }
    
    // 他のPolyominoとの同形判定
    func isEquivalentShape(to other: Polyomino) -> Bool {
        return self.calculateShapeId() == other.calculateShapeId()
    }
}

enum AspectType {
    case slender
    case wide
    case balanced
}

enum ConvexityType {
    case none
    case left
    case right
    case center
}