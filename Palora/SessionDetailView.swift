import SwiftUI
import AppKit

struct SessionDetailView: View {
    @State var session: SessionModel
    @State private var selectedTab: ContentTab = .summary
    @State private var showAudioPlayer = false
    private let fileManager = RecordingFileManager()
    
    enum ContentTab: String, CaseIterable {
        case summary = "Summary"
        case transcript = "Transcript"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerView
                
                Divider()
                
                // Action buttons
                actionButtonsView
                
                // Audio player (if shown)
                if showAudioPlayer && session.hasAudio {
                    Divider()
                    AudioPlayerView(audioURL: session.session.audioURL)
                }
                
                Divider()
                
                // Tab selector
                tabSelectorView
                
                // Content
                contentView
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadContent()
        }
        .onChange(of: selectedTab) { _, _ in
            loadContent()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.displayName)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                Label(session.formattedDate, systemImage: "calendar")
                Label(session.formattedTime, systemImage: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            Button(action: openFolder) {
                Label("Open Folder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            
            if session.hasAudio {
                Button(action: {
                    showAudioPlayer.toggle()
                }) {
                    Label(showAudioPlayer ? "Hide Audio Player" : "Play Audio", systemImage: showAudioPlayer ? "pause.circle" : "play.circle")
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var tabSelectorView: some View {
        Picker("Content", selection: $selectedTab) {
            ForEach(ContentTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .summary:
            summaryView
        case .transcript:
            transcriptView
        }
    }
    
    @ViewBuilder
    private var summaryView: some View {
        if session.isLoadingSummary {
            ProgressView("Loading summary...")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else if let summary = session.summary {
            Text(summary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if session.hasSummary {
            Text("Failed to load summary")
                .foregroundStyle(.secondary)
        } else {
            Text("No summary available")
                .foregroundStyle(.secondary)
                .italic()
        }
    }
    
    @ViewBuilder
    private var transcriptView: some View {
        if session.isLoadingTranscript {
            ProgressView("Loading transcript...")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else if let transcript = session.transcript {
            ScrollView {
                Text(transcript)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        } else if session.hasTranscript {
            Text("Failed to load transcript")
                .foregroundStyle(.secondary)
        } else {
            Text("No transcript available")
                .foregroundStyle(.secondary)
                .italic()
        }
    }
    
    private func loadContent() {
        Task {
            switch selectedTab {
            case .summary:
                await session.loadSummary(using: fileManager)
            case .transcript:
                await session.loadTranscript(using: fileManager)
            }
        }
    }
    
    private func openFolder() {
        NSWorkspace.shared.open(session.session.directory)
    }
}

