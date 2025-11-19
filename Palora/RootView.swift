import SwiftUI

@MainActor
struct RootView: View {
    @State private var selectedTab: Tab = .recordings
    
    enum Tab {
        case recordings
        case sessions
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordingsView()
                .tabItem {
                    Label("Recordings", systemImage: "mic.fill")
                }
                .tag(Tab.recordings)
            
            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: "list.bullet")
                }
                .tag(Tab.sessions)
        }
    }
}

@MainActor
struct RecordingsView: View {
    @State private var permission = AudioRecordingPermission()
    @State private var monitor = WatchedAppMonitor()
    @State private var processController = AudioProcessController()
    @State private var autoRecordingController: AutoRecordingController?

    var body: some View {
        Form { 
            // Watched Apps Status Section
            if !monitor.activeMatches.isEmpty {
                Section {
                    ForEach(monitor.activeMatches) { match in
                        HStack {
                            Image(nsImage: match.application.icon ?? NSWorkspace.shared.icon(for: .applicationBundle))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(match.configuration.name)
                                .font(.headline)
                            Spacer()
                            Text("Running")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("Watched Apps Detected")
                        .font(.headline)
                }
            }

            // Waiting for audio
            if let controller = autoRecordingController, !controller.pendingMatches.isEmpty {
                Section {
                    ForEach(Array(controller.pendingMatches.values), id: \.id) { pending in
                        HStack {
                            Image(nsImage: pending.match.application.icon ?? NSWorkspace.shared.icon(for: .applicationBundle))
                                .resizable()
                                .frame(width: 20, height: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(pending.match.configuration.name)
                                    .font(.headline)
                                Text("Waiting for meeting audio…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Auto-Recording (Waiting)")
                        .font(.headline)
                }
            }
            
            // Auto-Recording Status Section
            if let controller = autoRecordingController, !controller.activeRecordings.isEmpty {
                Section {
                    ForEach(Array(controller.activeRecordings.values), id: \.id) { recording in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(nsImage: recording.match.application.icon ?? NSWorkspace.shared.icon(for: .applicationBundle))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(recording.match.configuration.name)
                                    .font(.headline)
                                Spacer()
                                Text("Recording")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                TimelineView(.periodic(from: recording.startTime, by: 1.0)) { _ in
                                    Text(formatDuration(recording.duration))
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                            }
                            Text(recording.recorder.fileURL.lastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Auto-Recording")
                        .font(.headline)
                }
            }
            
            switch permission.status {
            case .unknown:
                requestPermissionView
            case .authorized:
                recordingView
            case .denied:
                permissionDeniedView
            }
        }
        .formStyle(.grouped)
        .onAppear {
            processController.activate()
            
            autoRecordingController = AutoRecordingController(processController: processController)
            
            monitor.onAppAppeared = { match in
                autoRecordingController?.handleAppAppeared(match)
            }
            
            monitor.onAppDisappeared = { match in
                autoRecordingController?.handleAppDisappeared(match)
            }
            
            monitor.startMonitoring()
        }
        .onDisappear {
            monitor.stopMonitoring()
            autoRecordingController?.cleanup()
            autoRecordingController = nil
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    @ViewBuilder
    private var requestPermissionView: some View {
        LabeledContent("Please Allow Audio Recording") {
            Button("Allow") {
                permission.request()
            }
        }
    }

    @ViewBuilder
    private var permissionDeniedView: some View {
        LabeledContent("Audio Recording Permission Required") {
            Button("Open System Settings") {
                NSWorkspace.shared.openSystemSettings()
            }
        }
    }

    @ViewBuilder
    private var recordingView: some View {
        ProcessSelectionView()
    }
}

extension NSWorkspace {
    func openSystemSettings() {
        guard let url = urlForApplication(withBundleIdentifier: "com.apple.systempreferences") else {
            assertionFailure("Failed to get System Settings app URL")
            return
        }

        openApplication(at: url, configuration: .init())
    }
}

#if DEBUG
#Preview {
    RootView()
}
#endif
