import SwiftUI
import Observation
import OSLog
import AppKit

@Observable
@MainActor
final class AutoRecordingController {

    struct PendingMatch: Identifiable {
        let match: WatchedAppMonitor.Match
        let createdAt: Date = Date()

        var id: pid_t { match.id }
    }

    struct ActiveRecording: Identifiable {
        let match: WatchedAppMonitor.Match
        let tap: ProcessTap
        let recorder: ProcessTapRecorder
        let session: RecordingFileManager.Session
        let startTime: Date
        var lastAudioActive: Date

        var id: pid_t { match.id }

        var duration: TimeInterval {
            Date.now.timeIntervalSince(startTime)
        }
    }
    
    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: AutoRecordingController.self))
    private let processController: AudioProcessController
    private let transcriptionService = OpenAITranscriptionService()
    private let summaryService = MeetingSummaryService()
    private let recordingFileManager = RecordingFileManager()

    private(set) var pendingMatches: [pid_t: PendingMatch] = [:]
    private(set) var activeRecordings: [pid_t: ActiveRecording] = [:]

    private var audioActivityTask: Task<Void, Never>?
    
    init(processController: AudioProcessController) {
        self.processController = processController
    }
    
    func handleAppAppeared(_ match: WatchedAppMonitor.Match) {
        guard pendingMatches[match.id] == nil, activeRecordings[match.id] == nil else {
            return
        }

        logger.info("Queued watched app \(match.configuration.name) [PID: \(match.id)] waiting for audio activity")
        pendingMatches[match.id] = PendingMatch(match: match)
        startAudioActivityWatcherIfNeeded()
    }

    func handleAppDisappeared(_ match: WatchedAppMonitor.Match) {
        logger.info("Watched app disappeared \(match.configuration.name) [PID: \(match.id)]")
        pendingMatches.removeValue(forKey: match.id)
        stopRecording(for: match)
        cleanupAudioWatcherIfIdle()
    }

    private func startAudioActivityWatcherIfNeeded() {
        guard audioActivityTask == nil else { return }

        audioActivityTask = Task { [weak self] in
            while let self = self {
                await MainActor.run {
                    self.evaluateAudioActivity()
                }

                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func cleanupAudioWatcherIfIdle() {
        guard pendingMatches.isEmpty, activeRecordings.isEmpty else { return }
        audioActivityTask?.cancel()
        audioActivityTask = nil
    }

    private func evaluateAudioActivity() {
        let processes = processController.processes

        // Check pending matches to see if they became audio-active
        for pending in Array(pendingMatches.values) {
            guard let process = processes.first(where: { $0.id == pending.match.id }) else {
                logger.debug("Pending app \(pending.match.configuration.name) [PID: \(pending.match.id)] not yet registered with Core Audio, will recheck")
                continue
            }

            if process.audioActive {
                logger.info("Detected audio activity for \(pending.match.configuration.name); starting recording")
                pendingMatches.removeValue(forKey: pending.match.id)
                startRecordingInternal(for: pending.match, audioProcess: process)
            }
        }

        // Check active recordings to see if audio has stopped
        for (pid, recording) in Array(activeRecordings) {
            guard let process = processes.first(where: { $0.id == pid }) else {
                logger.info("Process \(pid) disappeared, stopping recording")
                stopRecording(for: recording.match)
                continue
            }

            var updatedRecording = recording
            if process.audioActive {
                updatedRecording.lastAudioActive = Date()
                activeRecordings[pid] = updatedRecording
            } else if Date().timeIntervalSince(updatedRecording.lastAudioActive) > 5 {
                logger.info("No audio activity from \(recording.match.configuration.name) for 5s, stopping recording")
                stopRecording(for: recording.match)
            }
        }

        cleanupAudioWatcherIfIdle()
    }

    private func startRecordingInternal(for match: WatchedAppMonitor.Match, audioProcess: AudioProcess) {
        let pid = match.id
        
        logger.info("Starting auto-recording for \(match.configuration.name) [PID: \(pid)]")

        let startTime = Date.now

        let session: RecordingFileManager.Session
        do {
            session = try recordingFileManager.prepareSession(appName: match.configuration.name, startedAt: startTime)
        } catch {
            logger.error("Failed to prepare session directory: \(error.localizedDescription)")
            presentErrorAlert(title: "Recording Failed", message: "Could not prepare file storage: \(error.localizedDescription)")
            return
        }

        // For Zoom, we have two options:
        // 1. Tap Zoom directly (may cause instability)
        // 2. Tap system audio (captures everything)
        // For now, let's just tap Zoom and see if it works with the retry delays

        // Create tap
        let tap = ProcessTap(process: audioProcess)
        tap.activate()
        
        // Check for tap errors
        if tap.errorMessage != nil {
            logger.error("Failed to create tap for \(match.configuration.name): \(tap.errorMessage ?? "unknown error")")
            return
        }
        
        // Create recorder targeting the session directory
        let recorder = ProcessTapRecorder(fileURL: session.audioURL, tap: tap)
        
        // Start recording
        do {
            try recorder.start()

            // Store the active recording
            let recording = ActiveRecording(
                match: match,
                tap: tap,
                recorder: recorder,
                session: session,
                startTime: startTime,
                lastAudioActive: Date()
            )
            activeRecordings[pid] = recording

            logger.info("Successfully started recording to \(session.audioURL.lastPathComponent)")
        } catch {
            logger.error("Failed to start recording: \(error.localizedDescription)")
            tap.invalidate()
        }
    }
    
    func stopRecording(for match: WatchedAppMonitor.Match) {
        let pid = match.id
        
        guard let recording = activeRecordings[pid] else {
            logger.warning("No active recording found for PID \(pid)")
            return
        }
        
        logger.info("Stopping auto-recording for \(match.configuration.name) [PID: \(pid)]")
        
        // Stop the recorder
        recording.recorder.stop()

        let audioFileURL = recording.recorder.fileURL
        let session = recording.session
        let endTime = Date()

        // Clean up
        activeRecordings.removeValue(forKey: pid)
        logger.info("Re-arming watcher for \(match.configuration.name) [PID: \(pid)]")
        pendingMatches[pid] = PendingMatch(match: match)
        startAudioActivityWatcherIfNeeded()

        logger.info("Recording saved: \(audioFileURL.lastPathComponent)")

        // Start transcription in the background
        Task {
            let metadata = MeetingSummaryService.Metadata(
                appName: match.configuration.name,
                startedAt: recording.startTime,
                endedAt: endTime
            )
            await transcribeRecording(session: session, metadata: metadata)
        }
    }
    
    private func transcribeRecording(session: RecordingFileManager.Session, metadata: MeetingSummaryService.Metadata) async {
        logger.info("Starting transcription for \(session.audioURL.lastPathComponent)")

        do {
            let transcription = try await transcriptionService.transcribe(audioFile: session.audioURL)
            logger.info("Transcription completed: \(transcription.prefix(100))...")

            try recordingFileManager.saveTranscript(transcription, for: session)

            do {
                let summary = try await summaryService.summarize(transcript: transcription, metadata: metadata)
                try recordingFileManager.saveSummary(summary, for: session)
            } catch {
                logger.error("Meeting summary failed: \(error.localizedDescription)")
                await presentErrorAlert(title: "Summary Failed", message: error.localizedDescription)
            }
        } catch {
            logger.error("Transcription failed: \(error.localizedDescription)")
            await presentErrorAlert(title: "Transcription Failed", message: error.localizedDescription)
        }
    }

    @MainActor
    private func presentErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func stopAllRecordings() {
        logger.debug("Stopping all active recordings")
        
        for recording in activeRecordings.values {
            recording.recorder.stop()
        }
        
        activeRecordings.removeAll()
    }
    
    // Add a cleanup method that handles everything
    func cleanup() {
        logger.debug("Cleaning up AutoRecordingController")
        
        // Cancel the background task first
        audioActivityTask?.cancel()
        audioActivityTask = nil
        
        // Stop all recordings
        stopAllRecordings()
        
        // Clear pending matches
        pendingMatches.removeAll()
    }
}

