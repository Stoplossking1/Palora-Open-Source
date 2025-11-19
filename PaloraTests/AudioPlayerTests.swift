//
//  AudioPlayerTests.swift
//  PaloraTests
//
//  Created on 2025-11-18.
//

import XCTest
import AVFoundation
@testable import Palora

final class AudioPlayerTests: XCTestCase {
    var testAudioURL: URL!
    var testDirectory: URL!
    
    override func setUpWithError() throws {
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaloraTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        // Create a minimal WAV file for testing
        // Note: In a real scenario, you'd use a proper audio file
        // For now, we'll test error handling with invalid files
        testAudioURL = testDirectory.appendingPathComponent("test.wav")
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testDirectory)
    }
    
    @MainActor
    func testAudioPlayerInitialization() {
        let player = AudioPlayer()
        
        XCTAssertFalse(player.isPlaying, "Should not be playing initially")
        XCTAssertEqual(player.currentTime, 0, "Current time should be 0")
        XCTAssertEqual(player.duration, 0, "Duration should be 0")
        XCTAssertEqual(player.volume, 1.0, "Volume should default to 1.0")
        XCTAssertEqual(player.progress, 0, "Progress should be 0")
    }
    
    @MainActor
    func testAudioPlayerLoadInvalidFile() throws {
        let player = AudioPlayer()
        
        // Try to load a non-existent file
        XCTAssertThrowsError(try player.load(url: testAudioURL)) { error in
            // Should throw an error for invalid file
        }
        
        XCTAssertEqual(player.duration, 0, "Duration should remain 0 for invalid file")
        XCTAssertFalse(player.isPlaying, "Should not be playing")
    }
    
    @MainActor
    func testAudioPlayerVolumeSetting() {
        let player = AudioPlayer()
        
        player.volume = 0.5
        XCTAssertEqual(player.volume, 0.5, "Volume should be set to 0.5")
        
        player.volume = 0.0
        XCTAssertEqual(player.volume, 0.0, "Volume should be set to 0.0")
        
        player.volume = 1.0
        XCTAssertEqual(player.volume, 1.0, "Volume should be set to 1.0")
    }
    
    @MainActor
    func testAudioPlayerPlayPauseWithoutFile() {
        let player = AudioPlayer()
        
        // Try to play without loading a file
        player.play()
        
        // Should not crash, but won't actually play
        XCTAssertFalse(player.isPlaying, "Should not be playing without a file")
    }
    
    @MainActor
    func testAudioPlayerStop() {
        let player = AudioPlayer()
        
        player.stop()
        
        XCTAssertFalse(player.isPlaying, "Should not be playing after stop")
        XCTAssertEqual(player.currentTime, 0, "Current time should be reset")
        XCTAssertEqual(player.duration, 0, "Duration should be reset")
    }
    
    @MainActor
    func testAudioPlayerSeek() {
        let player = AudioPlayer()
        
        // Seek without a loaded file
        player.seek(to: 10.0)
        
        // Should not crash
        XCTAssertEqual(player.currentTime, 10.0, "Current time should be set")
    }
    
    @MainActor
    func testFormattedTime() {
        let player = AudioPlayer()
        
        XCTAssertEqual(player.formattedCurrentTime, "00:00", "Should format zero time correctly")
        XCTAssertEqual(player.formattedDuration, "00:00", "Should format zero duration correctly")
    }
    
    @MainActor
    func testFormattedTimeWithValues() {
        let player = AudioPlayer()
        
        // Manually set time values (simulating playback)
        player.currentTime = 125.0 // 2 minutes 5 seconds
        player.duration = 300.0 // 5 minutes
        
        XCTAssertEqual(player.formattedCurrentTime, "02:05", "Should format 125 seconds as 02:05")
        XCTAssertEqual(player.formattedDuration, "05:00", "Should format 300 seconds as 05:00")
    }
    
    @MainActor
    func testProgressCalculation() {
        let player = AudioPlayer()
        
        player.duration = 100.0
        player.currentTime = 25.0
        
        XCTAssertEqual(player.progress, 0.25, accuracy: 0.01, "Progress should be 25%")
        
        player.currentTime = 50.0
        XCTAssertEqual(player.progress, 0.5, accuracy: 0.01, "Progress should be 50%")
        
        player.currentTime = 100.0
        XCTAssertEqual(player.progress, 1.0, accuracy: 0.01, "Progress should be 100%")
    }
    
    @MainActor
    func testProgressWithZeroDuration() {
        let player = AudioPlayer()
        
        player.currentTime = 10.0
        player.duration = 0
        
        XCTAssertEqual(player.progress, 0, "Progress should be 0 when duration is 0")
    }
}

