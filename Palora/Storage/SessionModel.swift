import Foundation
import SwiftUI

/// Enhanced session model for UI display with loading state and computed properties
@Observable
final class SessionModel: Identifiable, Hashable {
    let session: RecordingFileManager.Session
    
    var id: String {
        session.directory.path
    }
    
    static func == (lhs: SessionModel, rhs: SessionModel) -> Bool {
            lhs.id == rhs.id
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    
    // Loading state
    var isLoadingTranscript = false
    var isLoadingSummary = false
    var transcript: String?
    var summary: String?
    
    // File existence checks
    var hasAudio: Bool
    var hasTranscript: Bool
    var hasSummary: Bool
    
    // Computed display properties
    var formattedDate: String {
        dateFormatter.string(from: session.startedAt)
    }
    
    var formattedTime: String {
        timeFormatter.string(from: session.startedAt)
    }
    
    var formattedDateTime: String {
        dateTimeFormatter.string(from: session.startedAt)
    }
    
    var displayName: String {
        session.appName
    }
    
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private let dateTimeFormatter: DateFormatter
    private let fileManager: FileManager
    
    init(session: RecordingFileManager.Session, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
        
        // Setup date formatters
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        self.dateFormatter = df
        
        let tf = DateFormatter()
        tf.dateStyle = .none
        tf.timeStyle = .short
        self.timeFormatter = tf
        
        let dtf = DateFormatter()
        dtf.dateStyle = .medium
        dtf.timeStyle = .short
        self.dateTimeFormatter = dtf
        
        // Check file existence
        self.hasAudio = fileManager.fileExists(atPath: session.audioURL.path)
        self.hasTranscript = fileManager.fileExists(atPath: session.transcriptURL.path)
        self.hasSummary = fileManager.fileExists(atPath: session.summaryURL.path)
    }
    
    /// Loads the transcript content asynchronously
    func loadTranscript(using manager: RecordingFileManager) async {
        guard !isLoadingTranscript, transcript == nil else { return }
        
        isLoadingTranscript = true
        defer { isLoadingTranscript = false }
        
        transcript = manager.readTranscript(for: session)
    }
    
    /// Loads the summary content asynchronously
    func loadSummary(using manager: RecordingFileManager) async {
        guard !isLoadingSummary, summary == nil else { return }
        
        isLoadingSummary = true
        defer { isLoadingSummary = false }
        
        summary = manager.readSummary(for: session)
    }
}

