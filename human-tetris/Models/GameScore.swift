//
//  GameScore.swift
//  human-tetris
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import Foundation
import SwiftData

@Model
final class GameScore {
    var timestamp: Date
    var finalScore: Int
    var linesCleared: Int
    var maxIoU: Float
    var averageIoU: Float
    var playTimeSeconds: Int
    var diversityIndex: Float
    var difficulty: String
    
    init(timestamp: Date = Date(), finalScore: Int, linesCleared: Int, maxIoU: Float, averageIoU: Float, playTimeSeconds: Int, diversityIndex: Float, difficulty: String) {
        self.timestamp = timestamp
        self.finalScore = finalScore
        self.linesCleared = linesCleared
        self.maxIoU = maxIoU
        self.averageIoU = averageIoU
        self.playTimeSeconds = playTimeSeconds
        self.diversityIndex = diversityIndex
        self.difficulty = difficulty
    }
}

@Model
final class Settings {
    var difficulty: String
    var mosaicEnabled: Bool
    var inputStyle: String
    var targetingEnabled: Bool
    var missionEnabled: Bool
    
    init(difficulty: String = "normal", mosaicEnabled: Bool = false, inputStyle: String = "buttons", targetingEnabled: Bool = true, missionEnabled: Bool = false) {
        self.difficulty = difficulty
        self.mosaicEnabled = mosaicEnabled
        self.inputStyle = inputStyle
        self.targetingEnabled = targetingEnabled
        self.missionEnabled = missionEnabled
    }
}