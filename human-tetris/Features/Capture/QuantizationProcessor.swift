//
//  QuantizationProcessor.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation
import CoreVideo
import Accelerate
import Vision

class QuantizationProcessor: ObservableObject {
    @Published var currentGrid = Grid4x3()
    @Published var occupancyRates: [[Float]] = Array(repeating: Array(repeating: 0.0, count: 3), count: 4)
    @Published var isStable = false
    @Published var stableTime: TimeInterval = 0
    
    private var lastStableGrid: Grid4x3?
    private var stableStartTime: Date?
    private let stableThreshold: TimeInterval = 0.4
    private var adaptiveThreshold: Float = 0.45
    
    private let minThreshold: Float = 0.35
    private let maxThreshold: Float = 0.55
    private let adaptationRate: Float = 0.01
    
    func quantize(mask: CVPixelBuffer, roi: CGRect, threshold: Float = 0.45) -> Grid4x3 {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(mask) else {
            return Grid4x3()
        }
        
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        
        let roiX = Int(roi.origin.x)
        let roiY = Int(roi.origin.y)
        let roiWidth = Int(roi.width)
        let roiHeight = Int(roi.height)
        
        let cellWidth = roiWidth / 3
        let cellHeight = roiHeight / 4
        
        var newOccupancyRates: [[Float]] = Array(repeating: Array(repeating: 0.0, count: 3), count: 4)
        var grid = Grid4x3()
        
        for row in 0..<4 {
            for col in 0..<3 {
                let cellStartX = roiX + col * cellWidth
                let cellStartY = roiY + row * cellHeight
                let cellEndX = min(cellStartX + cellWidth, width)
                let cellEndY = min(cellStartY + cellHeight, height)
                
                var totalPixels = 0
                var foregroundPixels = 0
                
                for y in cellStartY..<cellEndY {
                    for x in cellStartX..<cellEndX {
                        if x >= 0 && x < width && y >= 0 && y < height {
                            let pixelOffset = y * bytesPerRow + x
                            let pixelValue = baseAddress.load(fromByteOffset: pixelOffset, as: UInt8.self)
                            
                            totalPixels += 1
                            if pixelValue > 127 {
                                foregroundPixels += 1
                            }
                        }
                    }
                }
                
                let occupancyRate = totalPixels > 0 ? Float(foregroundPixels) / Float(totalPixels) : 0.0
                newOccupancyRates[row][col] = occupancyRate
                grid[row, col] = occupancyRate > threshold
            }
        }
        
        DispatchQueue.main.async {
            self.occupancyRates = newOccupancyRates
            self.updateStability(with: grid)
            self.currentGrid = grid
        }
        
        return grid
    }
    
    private func updateStability(with grid: Grid4x3) {
        let currentTime = Date()
        
        if let lastGrid = lastStableGrid, lastGrid == grid {
            if stableStartTime == nil {
                stableStartTime = currentTime
            }
            
            if let startTime = stableStartTime {
                stableTime = currentTime.timeIntervalSince(startTime)
                isStable = stableTime >= stableThreshold
            }
        } else {
            lastStableGrid = grid
            stableStartTime = nil
            stableTime = 0
            isStable = false
        }
    }
    
    func adjustThreshold(basedOnSuccess success: Bool) {
        if success {
            adaptiveThreshold = max(minThreshold, adaptiveThreshold - adaptationRate)
        } else {
            adaptiveThreshold = min(maxThreshold, adaptiveThreshold + adaptationRate)
        }
    }
    
    func getAdaptiveThreshold() -> Float {
        return adaptiveThreshold
    }
    
    func reset() {
        currentGrid = Grid4x3()
        occupancyRates = Array(repeating: Array(repeating: 0.0, count: 3), count: 4)
        lastStableGrid = nil
        stableStartTime = nil
        stableTime = 0
        isStable = false
    }
    
    func applyMorphologyOperations(to grid: inout Grid4x3) {
        var processedGrid = grid
        
        for row in 0..<4 {
            for col in 0..<3 {
                let neighbors = getNeighbors(row: row, col: col, in: grid)
                let onNeighbors = neighbors.filter { grid[$0.row, $0.col] }.count
                
                if grid[row, col] {
                    if onNeighbors < 2 {
                        processedGrid[row, col] = false
                    }
                } else {
                    if onNeighbors >= 3 {
                        processedGrid[row, col] = true
                    }
                }
            }
        }
        
        grid = processedGrid
    }
    
    private func getNeighbors(row: Int, col: Int, in grid: Grid4x3) -> [(row: Int, col: Int)] {
        let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        var neighbors: [(row: Int, col: Int)] = []
        
        for (dr, dc) in directions {
            let newRow = row + dr
            let newCol = col + dc
            
            if newRow >= 0 && newRow < 4 && newCol >= 0 && newCol < 3 {
                neighbors.append((row: newRow, col: newCol))
            }
        }
        
        return neighbors
    }
    
    func removeSmallComponents(from grid: inout Grid4x3, minSize: Int = 2) {
        var visited = Array(repeating: Array(repeating: false, count: 3), count: 4)
        
        for row in 0..<4 {
            for col in 0..<3 {
                if grid[row, col] && !visited[row][col] {
                    let component = floodFill(grid: grid, visited: &visited, startRow: row, startCol: col)
                    
                    if component.count < minSize {
                        for (r, c) in component {
                            grid[r, c] = false
                        }
                    }
                }
            }
        }
    }
    
    private func floodFill(grid: Grid4x3, visited: inout [[Bool]], startRow: Int, startCol: Int) -> [(Int, Int)] {
        var component: [(Int, Int)] = []
        var stack: [(Int, Int)] = [(startRow, startCol)]
        
        while !stack.isEmpty {
            let (row, col) = stack.removeLast()
            
            if visited[row][col] || !grid[row, col] {
                continue
            }
            
            visited[row][col] = true
            component.append((row, col))
            
            let neighbors = getNeighbors(row: row, col: col, in: grid)
            for (r, c) in neighbors {
                if !visited[r][c] && grid[r, c] {
                    stack.append((r, c))
                }
            }
        }
        
        return component
    }
}