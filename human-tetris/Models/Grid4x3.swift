//
//  Grid3x4.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation

struct Grid4x3: Equatable {
    var on: [[Bool]]
    
    init() {
        self.on = Array(repeating: Array(repeating: false, count: 3), count: 4)
    }
    
    init(_ on: [[Bool]]) {
        precondition(on.count == 4 && on.allSatisfy { $0.count == 3 }, "Grid4x3 must be 4 rows x 3 columns")
        self.on = on
    }
    
    subscript(row: Int, col: Int) -> Bool {
        get { on[row][col] }
        set { on[row][col] = newValue }
    }
    
    var onCells: [(row: Int, col: Int)] {
        var cells: [(row: Int, col: Int)] = []
        for row in 0..<4 {
            for col in 0..<3 {
                if on[row][col] {
                    cells.append((row: row, col: col))
                }
            }
        }
        return cells
    }
    
    var centroidX: Double {
        let onCells = self.onCells
        guard !onCells.isEmpty else { return 0.0 }
        
        let sumX = onCells.reduce(0.0) { $0 + Double($1.col) }
        let avgX = sumX / Double(onCells.count)
        return avgX / 2.0 // Normalize to [0, 1] (3 columns: 0,1,2 -> max index 2, so /2.0)
    }
    
    func occupancyRate(at row: Int, col: Int) -> Float {
        return on[row][col] ? 1.0 : 0.0
    }
}