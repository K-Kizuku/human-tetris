//
//  SimpleCountdownTests.swift
//  human-tetrisTests
//
//  Created by Kotani Kizuku on 2025/08/16.
//

import XCTest
import Foundation
@testable import human_tetris

final class SimpleCountdownTests: XCTestCase {
    
    var countdownManager: CountdownManager!
    
    override func setUpWithError() throws {
        countdownManager = CountdownManager()
    }
    
    override func tearDownWithError() throws {
        countdownManager = nil
    }
    
    // MARK: - Basic Countdown Tests
    
    func testCountdownBasicFunctionality() throws {
        let expectation = XCTestExpectation(description: "Basic countdown test")
        
        let delegate = TestCountdownDelegate()
        countdownManager.delegate = delegate
        
        var countUpdates: [Int] = []
        var zeroReached = false
        
        delegate.onCountUpdate = { count in
            countUpdates.append(count)
            print("Count update: \(count)")
        }
        
        delegate.onZeroReached = {
            zeroReached = true
            print("Zero reached!")
            expectation.fulfill()
        }
        
        // カウントダウン開始
        countdownManager.startCountdown()
        
        // 4秒待機
        wait(for: [expectation], timeout: 5.0)
        
        // 基本的な動作確認
        XCTAssertTrue(zeroReached, "Countdown should reach zero")
        XCTAssertFalse(countUpdates.isEmpty, "Should receive count updates")
        XCTAssertTrue(countUpdates.contains(3), "Should receive count 3")
        XCTAssertTrue(countUpdates.contains(2), "Should receive count 2")
        XCTAssertTrue(countUpdates.contains(1), "Should receive count 1")
    }
    
    func testCountdownTimingAccuracy() throws {
        let expectation = XCTestExpectation(description: "Countdown timing accuracy")
        
        let delegate = TestCountdownDelegate()
        countdownManager.delegate = delegate
        
        let startTime = Date()
        var endTime: Date?
        
        delegate.onZeroReached = {
            endTime = Date()
            expectation.fulfill()
        }
        
        countdownManager.startCountdown()
        wait(for: [expectation], timeout: 5.0)
        
        // タイミング精度チェック
        guard let endTime = endTime else {
            XCTFail("End time should be recorded")
            return
        }
        
        let actualDuration = endTime.timeIntervalSince(startTime)
        let expectedDuration: TimeInterval = 3.0
        let precision = abs(actualDuration - expectedDuration)
        
        print("Expected: \(expectedDuration)s, Actual: \(String(format: "%.3f", actualDuration))s, Precision: \(String(format: "%.3f", precision * 1000))ms")
        
        // ±100ms（0.1秒）の精度でテスト（より緩い条件）
        XCTAssertLessThan(precision, 0.1, "Countdown timing should be within ±100ms. Precision: \(precision * 1000)ms")
    }
    
    func testCountdownCancellation() throws {
        let expectation = XCTestExpectation(description: "Countdown cancellation")
        
        let delegate = TestCountdownDelegate()
        countdownManager.delegate = delegate
        
        var cancelledProperly = false
        
        delegate.onCountUpdate = { count in
            if count == 2 {
                // カウント2の時点でキャンセル
                self.countdownManager.stopCountdown()
                
                // 少し待ってからテスト完了
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    cancelledProperly = !self.countdownManager.isCountingDown
                    expectation.fulfill()
                }
            }
        }
        
        delegate.onZeroReached = {
            XCTFail("Countdown should have been cancelled before reaching zero")
        }
        
        countdownManager.startCountdown()
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertTrue(cancelledProperly, "Countdown should be cancelled properly")
    }
    
    func testMultipleCountdowns() throws {
        let testRuns = 3
        var allDurations: [TimeInterval] = []
        
        for run in 1...testRuns {
            let expectation = XCTestExpectation(description: "Multiple countdown test run \(run)")
            
            let delegate = TestCountdownDelegate()
            countdownManager.delegate = delegate
            
            let startTime = Date()
            
            delegate.onZeroReached = {
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)
                allDurations.append(duration)
                print("Run \(run): Duration \(String(format: "%.3f", duration))s")
                expectation.fulfill()
            }
            
            countdownManager.startCountdown()
            wait(for: [expectation], timeout: 5.0)
            
            // 次のテスト前に少し待機
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // 全ての実行結果をチェック
        XCTAssertEqual(allDurations.count, testRuns, "Should complete all test runs")
        
        for (index, duration) in allDurations.enumerated() {
            let precision = abs(duration - 3.0)
            XCTAssertLessThan(precision, 0.15, "Run \(index + 1) should be within ±150ms. Duration: \(duration)s")
        }
        
        // 一貫性チェック
        let maxDuration = allDurations.max() ?? 0
        let minDuration = allDurations.min() ?? 0
        let variation = maxDuration - minDuration
        
        print("Duration variation: \(String(format: "%.3f", variation * 1000))ms")
        XCTAssertLessThan(variation, 0.2, "Duration variation should be within 200ms")
    }
    
    func testProgressTracking() throws {
        let expectation = XCTestExpectation(description: "Progress tracking test")
        
        let delegate = TestCountdownDelegate()
        countdownManager.delegate = delegate
        
        var progressValues: [Double] = []
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            progressValues.append(self.countdownManager.progress)
        }
        
        delegate.onZeroReached = {
            progressTimer.invalidate()
            expectation.fulfill()
        }
        
        countdownManager.startCountdown()
        wait(for: [expectation], timeout: 5.0)
        
        // プログレス値をチェック
        XCTAssertFalse(progressValues.isEmpty, "Should capture progress values")
        
        let finalProgress = progressValues.last ?? 0.0
        XCTAssertGreaterThan(finalProgress, 0.9, "Final progress should be close to 1.0. Actual: \(finalProgress)")
        
        print("Progress samples: \(progressValues.count), Final progress: \(finalProgress)")
    }
}

// TestCountdownDelegate is defined in CountdownPrecisionTests.swift