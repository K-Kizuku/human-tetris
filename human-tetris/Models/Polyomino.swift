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
        let centroid = self.centroid
        let rotatedCells = cells.map { cell in
            let relX = Double(cell.x) - centroid.x
            let relY = Double(cell.y) - centroid.y
            
            let newX = -relY + centroid.x
            let newY = relX + centroid.y
            
            return (x: Int(round(newX)), y: Int(round(newY)))
        }
        
        return Polyomino(cells: normalize(rotatedCells), rot: rot + 1)
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