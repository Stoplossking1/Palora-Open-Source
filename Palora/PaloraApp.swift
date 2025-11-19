import SwiftUI

let kAppSubsystem = "codes.rambo.Palora"

@main
struct PaloraApp: App {
    @State private var monitor = WatchedAppMonitor()
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    monitor.onAppAppeared = { match in
                        print("✅ APPEARED: \(match.configuration.name) [PID: \(match.id)]")
                    }
                    monitor.onAppDisappeared = { match in
                        print("❌ DISAPPEARED: \(match.configuration.name) [PID: \(match.id)]")
                    }
                    monitor.startMonitoring()
                }
        }
    }
}
