//
//  SessionModelTests.swift
//  PaloraTests
//
//  Created on 2025-11-18.
//

import XCTest
@testable import Palora

final class SessionModelTests: XCTestCase {
    var testSession: RecordingFileManager.Session!
    var testDirectory: URL!
    
    override func setUpWithError() throws {
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaloraTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        testSession = RecordingFileManager.Session(
            directory: testDirectory,
            audioURL: testDirectory.appendingPathComponent("audio.wav"),
            transcriptURL: testDirectory.appendingPathComponent("transcript.txt"),
            summaryURL: testDirectory.appendingPathComponent("summary.md"),
            appName: "Zoom",
            startedAt: Date()
        )
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testDirectory)
    }
    
    func testSessionModelInitialization() {
        let model = SessionModel(session: testSession)
        
        XCTAssertEqual(model.session.appName, "Zoom", "App name should match")
        XCTAssertEqual(model.displayName, "Zoom", "Display name should match app name")
        XCTAssertFalse(model.formattedDate.isEmpty, "Formatted date should not be empty")
        XCTAssertFalse(model.formattedTime.isEmpty, "Formatted time should not be empty")
        XCTAssertFalse(model.formattedDateTime.isEmpty, "Formatted date time should not be empty")
    }
    
    func testFileExistenceChecks() throws {
        // Create audio file
        try "test".write(to: testSession.audioURL, atomically: true, encoding: .utf8)
        
        let model = SessionModel(session: testSession)
        
        XCTAssertTrue(model.hasAudio, "Should detect audio file exists")
        XCTAssertFalse(model.hasTranscript, "Should detect transcript file doesn't exist")
        XCTAssertFalse(model.hasSummary, "Should detect summary file doesn't exist")
    }
    
    func testFileExistenceChecksAllFiles() throws {
        // Create all files
        try "audio".write(to: testSession.audioURL, atomically: true, encoding: .utf8)
        try "transcript".write(to: testSession.transcriptURL, atomically: true, encoding: .utf8)
        try "summary".write(to: testSession.summaryURL, atomically: true, encoding: .utf8)
        
        let model = SessionModel(session: testSession)
        
        XCTAssertTrue(model.hasAudio, "Should detect audio file")
        XCTAssertTrue(model.hasTranscript, "Should detect transcript file")
        XCTAssertTrue(model.hasSummary, "Should detect summary file")
    }
    
    func testLoadTranscript() async throws {
        // Create transcript file
        let testTranscript = "This is a test transcript."
        try testTranscript.write(to: testSession.transcriptURL, atomically: true, encoding: .utf8)
        
        let model = SessionModel(session: testSession)
        let fileManager = RecordingFileManager()
        
        XCTAssertNil(model.transcript, "Transcript should be nil initially")
        XCTAssertFalse(model.isLoadingTranscript, "Should not be loading initially")
        
        await model.loadTranscript(using: fileManager)
        
        XCTAssertEqual(model.transcript, testTranscript, "Transcript should be loaded")
        XCTAssertFalse(model.isLoadingTranscript, "Should not be loading after completion")
    }
    
    func testLoadSummary() async throws {
        // Create summary file
        let testSummary = "# Test Summary"
        try testSummary.write(to: testSession.summaryURL, atomically: true, encoding: .utf8)
        
        let model = SessionModel(session: testSession)
        let fileManager = RecordingFileManager()
        
        XCTAssertNil(model.summary, "Summary should be nil initially")
        XCTAssertFalse(model.isLoadingSummary, "Should not be loading initially")
        
        await model.loadSummary(using: fileManager)
        
        XCTAssertEqual(model.summary, testSummary, "Summary should be loaded")
        XCTAssertFalse(model.isLoadingSummary, "Should not be loading after completion")
    }
    
    func testLoadTranscriptFromMissingFile() async {
        let model = SessionModel(session: testSession)
        let fileManager = RecordingFileManager()
        
        await model.loadTranscript(using: fileManager)
        
        XCTAssertNil(model.transcript, "Transcript should remain nil when file doesn't exist")
    }
    
    func testLoadSummaryFromMissingFile() async {
        let model = SessionModel(session: testSession)
        let fileManager = RecordingFileManager()
        
        await model.loadSummary(using: fileManager)
        
        XCTAssertNil(model.summary, "Summary should remain nil when file doesn't exist")
    }
    
    func testSessionModelID() {
        let model1 = SessionModel(session: testSession)
        let model2 = SessionModel(session: testSession)
        
        XCTAssertEqual(model1.id, model2.id, "Same session should have same ID")
        XCTAssertEqual(model1.id, testSession.directory.path, "ID should be directory path")
    }
}

