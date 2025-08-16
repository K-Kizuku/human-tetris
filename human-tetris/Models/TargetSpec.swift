//
//  TargetSpec.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation

struct TargetSpec: Equatable {
    var k: Int
    var aspect: AspectType
    var convexity: ConvexityType
    var rot: Int
    var centroidX: Int
    
    init(k: Int, aspect: AspectType, convexity: ConvexityType = .none, rot: Int = 0, centroidX: Int) {
        precondition(k >= 3 && k <= 6, "Target size must be 3-6 cells")
        precondition(centroidX >= 0 && centroidX <= 9, "Centroid X must be in board range")
        
        self.k = k
        self.aspect = aspect
        self.convexity = convexity
        self.rot = rot % 4
        self.centroidX = centroidX
    }
    
    func matches(_ polyomino: Polyomino, spawnColumn: Int) -> Float {
        var score: Float = 0.0
        
        if polyomino.size == k {
            score += 0.3
        } else {
            score -= 0.1 * Float(abs(polyomino.size - k))
        }
        
        let polyAspect: AspectType
        if polyomino.isSlender {
            polyAspect = .slender
        } else if polyomino.isWide {
            polyAspect = .wide
        } else {
            polyAspect = .balanced
        }
        
        if polyAspect == aspect {
            score += 0.3
        }
        
        if abs(spawnColumn - centroidX) <= 1 {
            score += 0.2
        } else {
            score -= 0.05 * Float(abs(spawnColumn - centroidX))
        }
        
        if polyomino.rot % 4 == rot {
            score += 0.1
        }
        
        return max(0.0, min(1.0, score))
    }
}