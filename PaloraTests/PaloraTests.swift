//
//  AudioCapTests.swift
//  AudioCapTests
//
//  Created by cj on 2025-11-15.
//

import XCTest
@testable import Palora

final class PaloraTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Test transcription of an audio file using OpenAI Whisper API
    /// 
    /// **To use this test:**
    /// 1. Replace the `testAudioFilePath` below with the path to your WAV file
    /// 2. Make sure your OpenAI API key is set in `OpenAIConfig.swift`
    /// 3. Run the test (⌘U or Product > Test)
    func testTranscription() async throws {
        // TODO: Replace this with your actual WAV file path
        // Example: "/Users/cj/Downloads/test-audio.wav"
        let testAudioFilePath = "/Users/cj/Documents/zoom.us-784872692.wav"

        // Skip test if file doesn't exist (so CI doesn't fail)
        guard FileManager.default.fileExists(atPath: testAudioFilePath) else {
            throw XCTSkip("Test audio file not found at \(testAudioFilePath). Please update testAudioFilePath with a valid path.")
        }

        let audioFileURL = URL(fileURLWithPath: testAudioFilePath)
        let service = OpenAITranscriptionService()

        // Call transcription
        let transcription = try await service.transcribe(audioFile: audioFileURL)

        // Assertions
        XCTAssertFalse(transcription.isEmpty, "Transcription should not be empty")
        print("✅ Transcription successful!")
        print("📝 Result: \(transcription)")
    }

    func testMeetingSummary() async throws {
        guard OpenAIConfig.apiKey != "api-key", !OpenAIConfig.apiKey.isEmpty else {
            throw XCTSkip("OpenAI API key not configured")
        }

        let transcript = """
        Alice: Let's review the launch checklist. Marketing still owes us the press kit.
        Bob: Engineering is ready. QA signed off yesterday.
        Alice: Great. Bob, please coordinate with Marketing to get the press kit by tomorrow.
        """

        let service = MeetingSummaryService()
        let now = Date()
        let metadata = MeetingSummaryService.Metadata(
            appName: "UnitTest",
            startedAt: now.addingTimeInterval(-900),
            endedAt: now
        )

        let summary = try await service.summarize(transcript: transcript, metadata: metadata)

        XCTAssertFalse(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Summary should not be empty")
        print("✅ Summary successful!\n\(summary)")
    }

}
