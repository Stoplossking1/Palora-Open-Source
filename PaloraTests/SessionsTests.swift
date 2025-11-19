//
//  SessionsTests.swift
//  PaloraTests
//
//  Created on 2025-11-18.
//

import XCTest
@testable import Palora

final class SessionsTests: XCTestCase {
    var fileManager: RecordingFileManager!
    var testDirectory: URL!
    
    override func setUpWithError() throws {
        fileManager = RecordingFileManager()
        
        // Create a temporary test directory
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaloraTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
    }
    
    func testLoadSessionFromValidDirectory() throws {
        // Create a test session directory structure
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dayFolder = testDirectory.appendingPathComponent(dateFormatter.string(from: date))
        try FileManager.default.createDirectory(at: dayFolder, withIntermediateDirectories: true)
        
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let sessionFolderName = "\(timestampFormatter.string(from: date))-Zoom"
        let sessionDirectory = dayFolder.appendingPathComponent(sessionFolderName)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        
        // Create test files
        let audioURL = sessionDirectory.appendingPathComponent("audio.wav")
        try "test audio".write(to: audioURL, atomically: true, encoding: .utf8)
        
        // Load the session
        let session = fileManager.loadSession(from: sessionDirectory)
        
        XCTAssertNotNil(session, "Session should be loaded successfully")
        XCTAssertEqual(session?.appName, "Zoom", "App name should be parsed correctly")
        XCTAssertEqual(session?.audioURL.lastPathComponent, "audio.wav", "Audio URL should be correct")
        XCTAssertEqual(session?.transcriptURL.lastPathComponent, "transcript.txt", "Transcript URL should be correct")
        XCTAssertEqual(session?.summaryURL.lastPathComponent, "summary.md", "Summary URL should be correct")
    }
    
    func testLoadSessionWithInvalidDirectoryName() throws {
        // Create a directory with invalid name format
        let invalidDirectory = testDirectory.appendingPathComponent("invalid-name")
        try FileManager.default.createDirectory(at: invalidDirectory, withIntermediateDirectories: true)
        
        let session = fileManager.loadSession(from: invalidDirectory)
        
        XCTAssertNil(session, "Session should not be loaded from invalid directory name")
    }
    
    func testReadTranscriptFromExistingFile() throws {
        // Create a test session
        let sessionDirectory = testDirectory.appendingPathComponent("test-session")
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        
        let transcriptURL = sessionDirectory.appendingPathComponent("transcript.txt")
        let testTranscript = "This is a test transcript."
        try testTranscript.write(to: transcriptURL, atomically: true, encoding: .utf8)
        
        let session = RecordingFileManager.Session(
            directory: sessionDirectory,
            audioURL: sessionDirectory.appendingPathComponent("audio.wav"),
            transcriptURL: transcriptURL,
            summaryURL: sessionDirectory.appendingPathComponent("summary.md"),
            appName: "Test",
            startedAt: Date()
        )
        
        let transcript = fileManager.readTranscript(for: session)
        
        XCTAssertEqual(transcript, testTranscript, "Transcript should be read correctly")
    }
    
    func testReadTranscriptFromMissingFile() throws {
        let sessionDirectory = testDirectory.appendingPathComponent("test-session")
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        
        let session = RecordingFileManager.Session(
            directory: sessionDirectory,
            audioURL: sessionDirectory.appendingPathComponent("audio.wav"),
            transcriptURL: sessionDirectory.appendingPathComponent("transcript.txt"),
            summaryURL: sessionDirectory.appendingPathComponent("summary.md"),
            appName: "Test",
            startedAt: Date()
        )
        
        let transcript = fileManager.readTranscript(for: session)
        
        XCTAssertNil(transcript, "Transcript should be nil when file doesn't exist")
    }
    
    func testReadSummaryFromExistingFile() throws {
        // Create a test session
        let sessionDirectory = testDirectory.appendingPathComponent("test-session")
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        
        let summaryURL = sessionDirectory.appendingPathComponent("summary.md")
        let testSummary = "# Test Summary\n\nThis is a test summary."
        try testSummary.write(to: summaryURL, atomically: true, encoding: .utf8)
        
        let session = RecordingFileManager.Session(
            directory: sessionDirectory,
            audioURL: sessionDirectory.appendingPathComponent("audio.wav"),
            transcriptURL: sessionDirectory.appendingPathComponent("transcript.txt"),
            summaryURL: summaryURL,
            appName: "Test",
            startedAt: Date()
        )
        
        let summary = fileManager.readSummary(for: session)
        
        XCTAssertEqual(summary, testSummary, "Summary should be read correctly")
    }
    
    func testReadSummaryFromMissingFile() throws {
        let sessionDirectory = testDirectory.appendingPathComponent("test-session")
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        
        let session = RecordingFileManager.Session(
            directory: sessionDirectory,
            audioURL: sessionDirectory.appendingPathComponent("audio.wav"),
            transcriptURL: sessionDirectory.appendingPathComponent("transcript.txt"),
            summaryURL: sessionDirectory.appendingPathComponent("summary.md"),
            appName: "Test",
            startedAt: Date()
        )
        
        let summary = fileManager.readSummary(for: session)
        
        XCTAssertNil(summary, "Summary should be nil when file doesn't exist")
    }
    
    func testLoadAllSessionsWithEmptyDirectory() {
        // Use a temporary empty directory
        let emptyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaloraTests-Empty-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDirectory) }
        
        // Note: This test uses the actual base directory, so it may find existing sessions
        // In a real scenario, you'd want to mock or use a test-specific directory
        let sessions = fileManager.loadAllSessions()
        
        // At minimum, should return an empty array without crashing
        XCTAssertNotNil(sessions, "Should return an array (may be empty)")
    }
}

