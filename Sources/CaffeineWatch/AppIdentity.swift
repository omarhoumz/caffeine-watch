import AppKit

/// A friendly name and icon for a process holding an assertion.
struct AppIdentity {
    let name: String
    let icon: NSImage

    private static var cache: [String: AppIdentity] = [:]

    /// System daemons have no app bundle, so they get a readable name here and a gear icon.
    private static let daemons = [
        "bluetoothd": "Bluetooth",
        "coreaudiod": "Audio",
        "sharingd": "AirDrop & Handoff",
        "useractivityd": "Handoff",
        "backupd": "Time Machine",
        "softwareupdated": "Software Update",
        "mds": "Spotlight", "mds_stores": "Spotlight",
        "airportd": "Wi-Fi",
        "locationd": "Location Services",
        "nsurlsessiond": "Background downloads",
        "cloudd": "iCloud", "bird": "iCloud Drive",
        "apsd": "Push notifications",
        "WindowServer": "Display",
    ]

    static func of(_ h: Holder) -> AppIdentity {
        let key = "\(h.pid) \(h.command)"
        if let hit = cache[key] { return hit }
        let id = resolve(h)
        cache[key] = id
        return id
    }

    private static func resolve(_ h: Holder) -> AppIdentity {
        // Helpers live inside their app (Chrome.app/…/Helper.app), so the outermost bundle names the app.
        if let r = h.command.range(of: ".app/") ?? h.command.range(of: ".app", options: .backwards),
           h.command.hasPrefix("/") {
            let path = String(h.command[..<r.lowerBound]) + ".app"
            if FileManager.default.fileExists(atPath: path) {
                let name = (FileManager.default.displayName(atPath: path) as NSString).deletingPathExtension
                return AppIdentity(name: name, icon: NSWorkspace.shared.icon(forFile: path))
            }
        }
        if let app = NSRunningApplication(processIdentifier: h.pid), let icon = app.icon {
            return AppIdentity(name: app.localizedName ?? h.processName, icon: icon)
        }
        let gear = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil) ?? NSImage()
        return AppIdentity(name: daemons[h.processName] ?? h.processName, icon: gear)
    }
}
