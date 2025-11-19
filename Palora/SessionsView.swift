import SwiftUI

@MainActor
struct SessionsView: View {
    @State private var sessions: [SessionModel] = []
    @State private var selectedSession: SessionModel?
    @State private var isLoading = true
    
    private let fileManager = RecordingFileManager()
    
    var body: some View {
        NavigationSplitView {
            if isLoading {
                ProgressView("Loading sessions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "mic.slash",
                    description: Text("No recording sessions found. Start a recording to see sessions here.")
                )
            } else {
                SessionListView(sessions: sessions, selectedSession: $selectedSession)
                    .navigationTitle("Sessions")
            }
        } detail: {
            if let selectedSession = selectedSession {
                SessionDetailView(session: selectedSession)
                    .id(selectedSession.id)  // Add this line - forces view recreation
                    .navigationTitle(selectedSession.displayName)
            } else {
                ContentUnavailableView(
                    "Select a Session",
                    systemImage: "list.bullet",
                    description: Text("Choose a session from the sidebar to view its details.")
                )
            }
        }
        .task {
            await loadSessions()
        }
    }
    
    private func loadSessions() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load sessions on background thread
        let loadedSessions = await Task.detached {
            fileManager.loadAllSessions()
        }.value
        
        // Convert to SessionModel on main thread
        sessions = loadedSessions.map { SessionModel(session: $0) }
        
        // Select first session if available
        if selectedSession == nil, let firstSession = sessions.first {
            selectedSession = firstSession
        }
    }
}

