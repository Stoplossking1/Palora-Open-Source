import AppKit

struct WatchedApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleID: String?
    let processName: String?

    init(name: String, bundleID: String? = nil, processName: String? = nil) {
        precondition(bundleID != nil || processName != nil, "WatchedApp requires at least a bundle ID or a process name")
        self.name = name
        self.bundleID = bundleID
        self.processName = processName
        self.id = bundleID ?? processName!
    }

    func matches(_ app: NSRunningApplication) -> Bool {
        if let bundleID, app.bundleIdentifier?.caseInsensitiveCompare(bundleID) == .orderedSame {
            return true
        }

        if let processName, matches(processName: processName, app: app) {
            return true
        }

        return false
    }

    private func matches(processName: String, app: NSRunningApplication) -> Bool {
        if let localizedName = app.localizedName, localizedName.caseInsensitiveCompare(processName) == .orderedSame {
            return true
        }

        if let executableName = app.executableURL?.deletingPathExtension().lastPathComponent,
           executableName.caseInsensitiveCompare(processName) == .orderedSame {
            return true
        }

        return false
    }
}

extension WatchedApp {
    static let defaultWatchList: [WatchedApp] = [
        WatchedApp(name: "Zoom", bundleID: "us.zoom.xos", processName: "zoom.us"),
        WatchedApp(name: "Zoom Audio Helper", bundleID: "us.zoom.caphost", processName: "caphost"),
        WatchedApp(name: "Zoom Clips", bundleID: "us.zoom.ZoomClips", processName: "ZoomClips")
    ]
}

