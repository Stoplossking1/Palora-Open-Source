import Foundation
import OSLog

/// Manages where recordings, transcripts, and summaries are stored on disk.
final class RecordingFileManager {

    struct Session: Sendable {
        let directory: URL
        let audioURL: URL
        let transcriptURL: URL
        let summaryURL: URL
        let appName: String
        let startedAt: Date
    }

    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: RecordingFileManager.self))
    private let fileManager: FileManager
    private let dayFormatter: DateFormatter
    private let timestampFormatter: DateFormatter

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = .current
        self.dayFormatter = dayFormatter

        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyyMMdd-HHmmss"
        timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
        timestampFormatter.timeZone = .current
        self.timestampFormatter = timestampFormatter
    }

    /// Prepares a directory for a new recording session and returns the file paths for artifacts.
    func prepareSession(appName: String, startedAt: Date) throws -> Session {
        let sanitizedAppName = sanitize(appName: appName)
        let baseDirectory = try ensureBaseDirectory()

        let dayFolder = baseDirectory.appendingPathComponent(dayFormatter.string(from: startedAt))
        try createDirectoryIfNeeded(at: dayFolder)

        let sessionFolderName = "\(timestampFormatter.string(from: startedAt))-\(sanitizedAppName)"
        let sessionDirectory = dayFolder.appendingPathComponent(sessionFolderName)
        try createDirectoryIfNeeded(at: sessionDirectory)

        let audioURL = sessionDirectory.appendingPathComponent("audio.wav")
        let transcriptURL = sessionDirectory.appendingPathComponent("transcript.txt")
        let summaryURL = sessionDirectory.appendingPathComponent("summary.md")

        logger.debug("Prepared recording session at \(sessionDirectory.path, privacy: .public)")

        return Session(
            directory: sessionDirectory,
            audioURL: audioURL,
            transcriptURL: transcriptURL,
            summaryURL: summaryURL,
            appName: appName,
            startedAt: startedAt
        )
    }

    func saveTranscript(_ text: String, for session: Session) throws {
        try text.write(to: session.transcriptURL, atomically: true, encoding: .utf8)
        logger.info("Transcript saved to \(session.transcriptURL.path, privacy: .public)")
    }

    func saveSummary(_ text: String, for session: Session) throws {
        try text.write(to: session.summaryURL, atomically: true, encoding: .utf8)
        logger.info("Summary saved to \(session.summaryURL.path, privacy: .public)")
    }

    // MARK: - Session Loading

    /// Loads all sessions from disk by scanning the base directory
    func loadAllSessions() -> [Session] {
        guard let baseDirectory = try? ensureBaseDirectory() else {
            logger.warning("Failed to get base directory for loading sessions")
            return []
        }

        var sessions: [Session] = []

        guard let dayFolders = try? fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            logger.warning("Failed to read base directory contents")
            return []
        }

        for dayFolder in dayFolders {
            guard let isDirectory = try? dayFolder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDirectory == true else {
                continue
            }

            guard let sessionFolders = try? fileManager.contentsOfDirectory(
                at: dayFolder,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for sessionFolder in sessionFolders {
                guard let isSessionDir = try? sessionFolder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                      isSessionDir == true else {
                    continue
                }

                if let session = loadSession(from: sessionFolder) {
                    sessions.append(session)
                }
            }
        }

        // Sort by date, newest first
        return sessions.sorted { $0.startedAt > $1.startedAt }
    }

    /// Loads a session from a directory URL by parsing the folder name
    func loadSession(from directoryURL: URL) -> Session? {
        let sessionFolderName = directoryURL.lastPathComponent

        // Parse folder name: YYYYMMDD-HHMMSS-AppName
        let components = sessionFolderName.split(separator: "-", maxSplits: 2, omittingEmptySubsequences: false)

        guard components.count >= 2 else {
            logger.warning("Invalid session folder name format: \(sessionFolderName, privacy: .public)")
            return nil
        }

        // Parse date and time
        let dateTimeString = "\(components[0])-\(components[1])"
        guard let startedAt = timestampFormatter.date(from: dateTimeString) else {
            logger.warning("Failed to parse date from folder name: \(dateTimeString, privacy: .public)")
            return nil
        }

        // Parse app name (everything after the timestamp)
        let appName = components.count > 2 ? String(components[2]) : "Unknown"

        let audioURL = directoryURL.appendingPathComponent("audio.wav")
        let transcriptURL = directoryURL.appendingPathComponent("transcript.txt")
        let summaryURL = directoryURL.appendingPathComponent("summary.md")

        return Session(
            directory: directoryURL,
            audioURL: audioURL,
            transcriptURL: transcriptURL,
            summaryURL: summaryURL,
            appName: appName,
            startedAt: startedAt
        )
    }

    /// Reads the transcript content from a session
    func readTranscript(for session: Session) -> String? {
        guard fileManager.fileExists(atPath: session.transcriptURL.path) else {
            logger.debug("Transcript file does not exist: \(session.transcriptURL.path, privacy: .public)")
            return nil
        }

        do {
            return try String(contentsOf: session.transcriptURL, encoding: .utf8)
        } catch {
            logger.error("Failed to read transcript: \(error.localizedDescription)")
            return nil
        }
    }

    /// Reads the summary content from a session
    func readSummary(for session: Session) -> String? {
        guard fileManager.fileExists(atPath: session.summaryURL.path) else {
            logger.debug("Summary file does not exist: \(session.summaryURL.path, privacy: .public)")
            return nil
        }

        do {
            return try String(contentsOf: session.summaryURL, encoding: .utf8)
        } catch {
            logger.error("Failed to read summary: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private func ensureBaseDirectory() throws -> URL {
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let baseDirectory = documentsDirectory.appendingPathComponent("Palora")
        try createDirectoryIfNeeded(at: baseDirectory)
        return baseDirectory
    }

    private func createDirectoryIfNeeded(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func sanitize(appName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = appName.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-_").union(.whitespacesAndNewlines))

        if sanitized.isEmpty {
            return "Meeting"
        }

        // Collapse duplicate separators to keep folder names tidy.
        let components = sanitized.split(whereSeparator: { $0 == "-" || $0 == "_" })
        return components.joined(separator: "-")
    }
}
