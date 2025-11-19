import SwiftUI
import AppKit

struct SessionListView: View {
    let sessions: [SessionModel]
    @Binding var selectedSession: SessionModel?
    
    var body: some View {
        List(selection: $selectedSession) {
            ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { date in
                Section {
                    ForEach(groupedSessions[date] ?? []) { session in
                        SessionRowView(session: session)
                            .tag(session)
                    }
                } header: {
                    Text(formatDate(date))
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    private var groupedSessions: [Date: [SessionModel]] {
        Dictionary(grouping: sessions) { session in
            Calendar.current.startOfDay(for: session.session.startedAt)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return formatter.string(from: date)
        }
    }
}

struct SessionRowView: View {
    let session: SessionModel
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon placeholder (could be enhanced with actual app icons)
            Image(systemName: iconForApp(session.displayName))
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(session.formattedTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // File status indicators
            HStack(spacing: 4) {
                if session.hasAudio {
                    Image(systemName: "waveform")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                if session.hasTranscript {
                    Image(systemName: "text.bubble")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                if session.hasSummary {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForApp(_ appName: String) -> String {
        let lowercased = appName.lowercased()
        if lowercased.contains("zoom") {
            return "video.fill"
        } else if lowercased.contains("meet") || lowercased.contains("google") {
            return "video.circle.fill"
        } else if lowercased.contains("teams") {
            return "person.3.fill"
        } else {
            return "mic.fill"
        }
    }
}

