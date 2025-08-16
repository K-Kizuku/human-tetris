//
//  ShapeExtractor.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation

struct CandidateShape {
    let cells: [(row: Int, col: Int)]
    let score: Float
    let iou: Float
    
    var size: Int { cells.count }
    
    func toPolyomino() -> Polyomino {
        let mappedCells = cells.map { (x: $0.col, y: $0.row) }
        return Polyomino(cells: mappedCells)
    }
}

struct BeamSearchNode {
    let cells: [(row: Int, col: Int)]
    let score: Float
    let upperBound: Float
    
    var size: Int { cells.count }
}

class ShapeExtractor: ObservableObject {
    @Published var candidates: [CandidateShape] = []
    @Published var bestCandidate: CandidateShape?
    
    private let scoreWeights = ScoreWeights()
    private let beamWidth = GameConfig.beamWidth
    private let maxBeamWidth = GameConfig.maxBeamWidth
    
    func extractBestShape(from grid: Grid3x4, targetSpec: TargetSpec? = nil) -> Polyomino? {
        let candidates = findCandidates(in: grid, targetSpec: targetSpec)
        
        DispatchQueue.main.async {
            self.candidates = candidates
            self.bestCandidate = candidates.first
        }
        
        return candidates.first?.toPolyomino()
    }
    
    private func findCandidates(in grid: Grid3x4, targetSpec: TargetSpec?) -> [CandidateShape] {
        let onCells = grid.onCells
        guard !onCells.isEmpty else { return [] }
        
        var allCandidates: [CandidateShape] = []
        
        for targetSize in GameConfig.minPieceSize...GameConfig.maxPieceSize {
            let candidates = beamSearchForSize(targetSize, in: grid, onCells: onCells, targetSpec: targetSpec)
            allCandidates.append(contentsOf: candidates)
        }
        
        return allCandidates.sorted { $0.score > $1.score }
    }
    
    private func beamSearchForSize(_ targetSize: Int, in grid: Grid3x4, onCells: [(row: Int, col: Int)], targetSpec: TargetSpec?) -> [CandidateShape] {
        var beam: [BeamSearchNode] = []
        
        for cell in onCells {
            let initialScore = calculateCellScore(cell, in: grid)
            let upperBound = calculateUpperBound(startingWith: [cell], targetSize: targetSize, onCells: onCells, grid: grid)
            
            beam.append(BeamSearchNode(cells: [cell], score: initialScore, upperBound: upperBound))
        }
        
        for currentSize in 1..<targetSize {
            var nextBeam: [BeamSearchNode] = []
            
            for node in beam {
                let expansions = expandNode(node, targetSize: targetSize, onCells: onCells, grid: grid)
                nextBeam.append(contentsOf: expansions)
            }
            
            nextBeam.sort { $0.upperBound > $1.upperBound }
            beam = Array(nextBeam.prefix(beamWidth))
            
            if beam.isEmpty {
                break
            }
        }
        
        return beam.filter { $0.size == targetSize }.map { node in
            let finalScore = calculateFinalScore(cells: node.cells, grid: grid, targetSpec: targetSpec)
            let iou = calculateIoU(cells: node.cells, grid: grid)
            return CandidateShape(cells: node.cells, score: finalScore, iou: iou)
        }
    }
    
    private func expandNode(_ node: BeamSearchNode, targetSize: Int, onCells: [(row: Int, col: Int)], grid: Grid3x4) -> [BeamSearchNode] {
        var expansions: [BeamSearchNode] = []
        let existingCells = Set(node.cells.map { "\($0.row),\($0.col)" })
        
        for cell in node.cells {
            let neighbors = getNeighbors(row: cell.row, col: cell.col)
            
            for neighbor in neighbors {
                let neighborKey = "\(neighbor.row),\(neighbor.col)"
                
                if !existingCells.contains(neighborKey) &&
                   neighbor.row >= 0 && neighbor.row < 3 &&
                   neighbor.col >= 0 && neighbor.col < 4 &&
                   grid[neighbor.row, neighbor.col] {
                    
                    let newCells = node.cells + [neighbor]
                    
                    if isConnected(cells: newCells) {
                        let newScore = calculatePartialScore(cells: newCells, grid: grid)
                        let upperBound = calculateUpperBound(startingWith: newCells, targetSize: targetSize, onCells: onCells, grid: grid)
                        
                        expansions.append(BeamSearchNode(cells: newCells, score: newScore, upperBound: upperBound))
                    }
                }
            }
        }
        
        return expansions
    }
    
    private func getNeighbors(row: Int, col: Int) -> [(row: Int, col: Int)] {
        return [
            (row: row - 1, col: col),
            (row: row + 1, col: col),
            (row: row, col: col - 1),
            (row: row, col: col + 1)
        ]
    }
    
    private func isConnected(cells: [(row: Int, col: Int)]) -> Bool {
        guard !cells.isEmpty else { return false }
        
        let cellSet = Set(cells.map { "\($0.row),\($0.col)" })
        var visited = Set<String>()
        var queue = [cells[0]]
        visited.insert("\(cells[0].row),\(cells[0].col)")
        
        while !queue.isEmpty {
            let current = queue.removeFirst()
            let neighbors = getNeighbors(row: current.row, col: current.col)
            
            for neighbor in neighbors {
                let key = "\(neighbor.row),\(neighbor.col)"
                if cellSet.contains(key) && !visited.contains(key) {
                    visited.insert(key)
                    queue.append(neighbor)
                }
            }
        }
        
        return visited.count == cells.count
    }
    
    private func calculateCellScore(_ cell: (row: Int, col: Int), in grid: Grid3x4) -> Float {
        let occupancyRate = grid.occupancyRate(at: cell.row, col: cell.col)
        return scoreWeights.w1 * occupancyRate
    }
    
    private func calculatePartialScore(cells: [(row: Int, col: Int)], grid: Grid3x4) -> Float {
        let occupancySum = cells.reduce(0.0) { sum, cell in
            sum + grid.occupancyRate(at: cell.row, col: cell.col)
        }
        
        let connectivity = calculateConnectivity(cells: cells)
        
        return scoreWeights.w1 * occupancySum + scoreWeights.w2 * connectivity
    }
    
    private func calculateFinalScore(cells: [(row: Int, col: Int)], grid: Grid3x4, targetSpec: TargetSpec?) -> Float {
        let occupancySum = cells.reduce(0.0) { sum, cell in
            sum + grid.occupancyRate(at: cell.row, col: cell.col)
        }
        
        let connectivity = calculateConnectivity(cells: cells)
        let aspectPenalty = calculateAspectPenalty(cells: cells)
        
        var score = scoreWeights.w1 * occupancySum + scoreWeights.w2 * connectivity - scoreWeights.w5 * aspectPenalty
        
        if let target = targetSpec {
            let polyomino = Polyomino(cells: cells.map { (x: $0.col, y: $0.row) })
            let spawnColumn = Int(grid.centroidX * 9)
            let targetMatch = target.matches(polyomino, spawnColumn: spawnColumn)
            score += scoreWeights.w4 * targetMatch
        }
        
        return score
    }
    
    private func calculateConnectivity(cells: [(row: Int, col: Int)]) -> Float {
        guard cells.count > 1 else { return 0.0 }
        
        let cellSet = Set(cells.map { "\($0.row),\($0.col)" })
        var internalEdges = 0
        
        for cell in cells {
            let neighbors = getNeighbors(row: cell.row, col: cell.col)
            for neighbor in neighbors {
                let key = "\(neighbor.row),\(neighbor.col)"
                if cellSet.contains(key) {
                    internalEdges += 1
                }
            }
        }
        
        let maxPossibleEdges = 2 * cells.count
        return Float(internalEdges) / Float(maxPossibleEdges)
    }
    
    private func calculateAspectPenalty(cells: [(row: Int, col: Int)]) -> Float {
        guard !cells.isEmpty else { return 0.0 }
        
        let rows = cells.map { $0.row }
        let cols = cells.map { $0.col }
        
        let minRow = rows.min()!
        let maxRow = rows.max()!
        let minCol = cols.min()!
        let maxCol = cols.max()!
        
        let height = maxRow - minRow + 1
        let width = maxCol - minCol + 1
        
        let aspectRatio = Float(max(height, width)) / Float(min(height, width))
        let threshold: Float = 1.8
        
        return max(0.0, aspectRatio - threshold)
    }
    
    private func calculateUpperBound(startingWith cells: [(row: Int, col: Int)], targetSize: Int, onCells: [(row: Int, col: Int)], grid: Grid3x4) -> Float {
        let currentScore = calculatePartialScore(cells: cells, grid: grid)
        let remainingCells = targetSize - cells.count
        
        guard remainingCells > 0 else { return currentScore }
        
        let availableCells = onCells.filter { cell in
            !cells.contains { $0.row == cell.row && $0.col == cell.col }
        }
        
        let topOccupancyRates = availableCells
            .map { grid.occupancyRate(at: $0.row, col: $0.col) }
            .sorted(by: >)
            .prefix(remainingCells)
        
        let maxAdditionalScore = topOccupancyRates.reduce(0.0, +) * scoreWeights.w1
        
        return currentScore + maxAdditionalScore
    }
    
    private func calculateIoU(cells: [(row: Int, col: Int)], grid: Grid3x4) -> Float {
        let cellSet = Set(cells.map { "\($0.row),\($0.col)" })
        let onCells = Set(grid.onCells.map { "\($0.row),\($0.col)" })
        
        let intersection = cellSet.intersection(onCells)
        let union = cellSet.union(onCells)
        
        guard !union.isEmpty else { return 0.0 }
        
        return Float(intersection.count) / Float(union.count)
    }
}