import AppKit
import Combine
import Observation
import OSLog

@Observable
final class WatchedAppMonitor {

    struct Match: Identifiable, Hashable {
        let configuration: WatchedApp
        let application: NSRunningApplication

        var id: pid_t { application.processIdentifier }
    }

    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: WatchedAppMonitor.self))
    private let watchedApps: [WatchedApp]
    private let workspace: NSWorkspace

    private var monitoringSubscription: AnyCancellable?

    private(set) var activeMatches: [Match] = []

    var onAppAppeared: ((Match) -> Void)?
    var onAppDisappeared: ((Match) -> Void)?

    init(watchedApps: [WatchedApp] = WatchedApp.defaultWatchList, workspace: NSWorkspace = .shared) {
        self.watchedApps = watchedApps
        self.workspace = workspace
    }

    func startMonitoring() {
        guard monitoringSubscription == nil else { return }

        logger.debug("Start monitoring watched apps: \(self.watchedApps.map(\.name).joined(separator: ", "))")
        ///Combine (Apple's reactive framework) is used to monitor the running applications.
        
        monitoringSubscription = workspace.publisher(for: \.runningApplications, options: [.initial, .new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                self?.handle(apps: apps)
            }
    }

    func stopMonitoring() {
        guard monitoringSubscription != nil else { return }

        logger.debug("Stop monitoring watched apps")

        monitoringSubscription?.cancel()
        monitoringSubscription = nil

        updateMatches(with: [])
    }

    private func handle(apps: [NSRunningApplication]) { // loops 
        let matches = apps.compactMap { app -> Match? in
            guard let configuration = watchedApps.first(where: { $0.matches(app) }) else { return nil }
            return Match(configuration: configuration, application: app)
        }

        updateMatches(with: matches)
    }

    private func updateMatches(with matches: [Match]) {
        let previousIDs = Set(activeMatches.map(\.id))
        let newIDs = Set(matches.map(\.id))

        let appeared = matches.filter { !previousIDs.contains($0.id) }
        let disappeared = activeMatches.filter { !newIDs.contains($0.id) }

        activeMatches = matches

        appeared.forEach { match in
            logger.info("Watched app appeared: \(match.configuration.name, privacy: .public) [pid: \(match.id)]")
            onAppAppeared?(match)
        }

        disappeared.forEach { match in
            logger.info("Watched app disappeared: \(match.configuration.name, privacy: .public) [pid: \(match.id)]")
            onAppDisappeared?(match)
        }
    }

    deinit {
        stopMonitoring()
    }
}

