//
//  CountdownPrecisionTests.swift
//  human-tetrisTests
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import XCTest
import Foundation
@testable import human_tetris

final class CountdownPrecisionTests: XCTestCase {
    
    var countdownManager: CountdownManager!
    var expectation: XCTestExpectation!
    var countdownStartTime: Date!
    var countdownEndTime: Date!
    var actualTimings: [TimeInterval] = []
    
    override func setUpWithError() throws {
        countdownManager = CountdownManager()
        actualTimings = []
    }
    
    override func tearDownWithError() throws {
        countdownManager = nil
        expectation = nil
    }
    
    // MARK: - Precision Tests
    
    func testCountdownTimingPrecision() throws {
        expectation = XCTestExpectation(description: "Countdown precision test")
        expectation.expectedFulfillmentCount = 1
        
        // CountdownManagerDelegateを実装
        let delegate = TestCountdownDelegate()
        countdownManager.delegate = delegate
        
        var countTimes: [Date] = []
        let startTime = Date()
        
        delegate.onCountUpdate = { count in
            let currentTime = Date()
            countTimes.append(currentTime)
            
            let expectedTime = startTime.addingTimeInterval(TimeInterval(4 - count)) // 3秒カウントダウン（3,2,1,0）
            let actualInterval = currentTime.timeIntervalSince(startTime)
            let expectedInterval = TimeInterval(4 - count)
            let precision = abs(actualInterval - expectedInterval)
            
            print("Count \(count): Expected \(expectedInterval)s, Actual \(String(format: "%.3f", actualInterval))s, Precision: \(String(format: "%.3f", precision * 1000))ms")
            
            // ±50ms（0.05秒）の精度を検証
            XCTAssertLessThan(precision, 0.05, "Countdown timing precision should be within ±50ms. Count: \(count), Precision: \(precision * 1000)ms")
        }
        
        delegate.onZeroReached = {
            let endTime = Date()
            let totalDuration = endTime.timeIntervalSince(startTime)
            let expectedDuration: TimeInterval = 3.0 // 3秒
            let finalPrecision = abs(totalDuration - expectedDuration)
            
            print("Total countdown duration: Expected \(expectedDuration)s, Actual \(String(format: "%.3f", totalDuration))s, Final Precision: \(String(format: "%.3f", finalPrecision * 1000))ms")
            
            // 全体の精度も±50ms以内
            XCTAssertLessThan(finalPrecision, 0.05, "Total countdown duration should be within ±50ms. Precision: \(finalPrecision * 1000)ms")
            
            self.expectation.fulfill()
        }
        
        // カウントダウン開始
        countdownManager.startCountdown()
        
        // 4秒待機（3秒カウントダウン + バッファ）
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testMultipleCountdownConsistency() throws {
        let testRuns = 5
        var allPrecisions: [TimeInterval] = []
        
        for run in 1...testRuns {
            expectation = XCTestExpectation(description: "Countdown consistency test run \(run)")
            
            let delegate = TestCountdownDelegate()
            countdownManager.delegate = delegate
            
            let startTime = Date()
            
            delegate.onZeroReached = {
                let endTime = Date()
                let totalDuration = endTime.timeIntervalSince(startTime)
                let expectedDuration: TimeInterval = 3.0
                let precision = abs(totalDuration - expectedDuration)
                
                allPrecisions.append(precision)
                print("Run \(run): Total duration \(String(format: "%.3f", totalDuration))s, Precision: \(String(format: "%.3f", precision * 1000))ms")
                
                self.expectation.fulfill()
            }
            
            countdownManager.startCountdown()
            wait(for: [expectation], timeout: 5.0)
            
            // 次のテスト前に少し待機
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // 全ての実行が±50ms以内
        for (index, precision) in allPrecisions.enumerated() {
            XCTAssertLessThan(precision, 0.05, "Run \(index + 1) precision should be within ±50ms. Precision: \(precision * 1000)ms")
        }
        
        // 平均精度を計算
        let averagePrecision = allPrecisions.reduce(0, +) / Double(allPrecisions.count)
        let maxPrecision = allPrecisions.max() ?? 0
        let minPrecision = allPrecisions.min() ?? 0
        
        print("Consistency Results:")
        print("- Average precision: \(String(format: "%.3f", averagePrecision * 1000))ms")
        print("- Max precision: \(String(format: "%.3f", maxPrecision * 1000))ms")
        print("- Min precision: \(String(format: "%.3f", minPrecision * 1000))ms")
        
        // 平均精度も±50ms以内
        XCTAssertLessThan(averagePrecision, 0.05, "Average precision should be within ±50ms")
    }
    
    func testCountdownCancellation() throws {
        expectation = XCTestExpectation(description: "Countdown cancellation test")
        
        let delegate = TestCountdownDelegate()
        countdownManager.delegate = delegate
        
        var cancelTime: Date?
        
        delegate.onCountUpdate = { count in
            if count == 2 {
                // カウント2の時点でキャンセル
                cancelTime = Date()
                self.countdownManager.stopCountdown()
                
                // 少し待ってからテスト完了
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.expectation.fulfill()
                }
            }
        }
        
        delegate.onZeroReached = {
            XCTFail("Countdown should have been cancelled before reaching zero")
        }
        
        countdownManager.startCountdown()
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertNotNil(cancelTime, "Cancel time should be recorded")
        XCTAssertFalse(countdownManager.isCountingDown, "Countdown should not be active after cancellation")
    }
    
    func testProgressAccuracy() throws {
        expectation = XCTestExpectation(description: "Progress accuracy test")
        
        let delegate = TestCountdownDelegate()
        countdownManager.delegate = delegate
        
        var progressMeasurements: [(time: TimeInterval, progress: Double)] = []
        let startTime = Date()
        
        // プログレス変更を監視（タイマーで代替）
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let currentTime = Date().timeIntervalSince(startTime)
            let currentProgress = self.countdownManager.progress
            progressMeasurements.append((time: currentTime, progress: currentProgress))
        }
        
        delegate.onZeroReached = {
            progressTimer.invalidate()
            
            // プログレス精度を検証
            for measurement in progressMeasurements {
                let expectedProgress = measurement.time / 3.0 // 3秒で1.0に到達
                let actualProgress = measurement.progress
                let progressError = abs(expectedProgress - actualProgress)
                
                // プログレスも±5%の精度内
                XCTAssertLessThan(progressError, 0.05, "Progress accuracy should be within ±5%. Time: \(measurement.time), Expected: \(expectedProgress), Actual: \(actualProgress)")
            }
            
            print("Progress measurements: \(progressMeasurements.count) samples")
            
            self.expectation.fulfill()
        }
        
        countdownManager.startCountdown()
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Test Delegate

class TestCountdownDelegate: CountdownManagerDelegate {
    var onCountUpdate: ((Int) -> Void)?
    var onZeroReached: (() -> Void)?
    var onError: ((Error) -> Void)?
    
    func countdownManager(_ manager: CountdownManager, didUpdateCount count: Int) {
        onCountUpdate?(count)
    }
    
    func countdownManagerDidReachZero(_ manager: CountdownManager) {
        onZeroReached?()
    }
    
    func countdownManager(_ manager: CountdownManager, didEncounterError error: Error) {
        onError?(error)
    }
}

// MARK: - Performance Tests

extension CountdownPrecisionTests {
    
    func testCountdownPerformance() throws {
        measure {
            let delegate = TestCountdownDelegate()
            countdownManager.delegate = delegate
            
            let expectation = XCTestExpectation(description: "Performance test")
            
            delegate.onZeroReached = {
                expectation.fulfill()
            }
            
            countdownManager.startCountdown()
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testMemoryUsageDuringCountdown() throws {
        weak var weakManager: CountdownManager?
        
        autoreleasepool {
            let manager = CountdownManager()
            weakManager = manager
            
            let delegate = TestCountdownDelegate()
            manager.delegate = delegate
            
            let expectation = XCTestExpectation(description: "Memory test")
            
            delegate.onZeroReached = {
                expectation.fulfill()
            }
            
            manager.startCountdown()
            wait(for: [expectation], timeout: 5.0)
        }
        
        // メモリリークなしを確認
        XCTAssertNil(weakManager, "CountdownManager should be deallocated after test")
    }
}