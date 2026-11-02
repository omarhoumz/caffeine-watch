import Foundation

struct Assertion: Hashable {
    let pid: Int32
    let processName: String
    let age: String
    let type: String
    let name: String
}

enum AssertionParser {
    private static let line = try! NSRegularExpression(
        pattern: #"^\s+pid (\d+)\((.+?)\): \[0x[0-9a-fA-F]+\] (\d+:\d+:\d+) (\w+) named: "(.*)""#
    )

    /// Parses the "Listed by owning process" section of `pmset -g assertions`.
    static func parse(_ output: String) -> [Assertion] {
        var result: [Assertion] = []
        var inSection = false
        for raw in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(raw)
            if s.hasPrefix("Listed by owning process") { inSection = true; continue }
            if s.hasPrefix("Kernel Assertions") { break }
            guard inSection else { continue }
            let ns = s as NSString
            guard let m = line.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { continue }
            func g(_ i: Int) -> String { ns.substring(with: m.range(at: i)) }
            guard let pid = Int32(g(1)) else { continue }
            result.append(Assertion(pid: pid, processName: g(2), age: g(3), type: g(4), name: g(5)))
        }
        return result
    }

    /// Assertions that actually keep the Mac awake. powerd's "while display is on",
    /// WindowServer's UserIsActive and BackgroundTask are always-present baseline noise.
    static func preventsSleep(_ a: Assertion) -> Bool {
        if a.processName == "powerd" { return false }
        return a.type.hasPrefix("Prevent") || (a.type.hasPrefix("No") && a.type.hasSuffix("SleepAssertion"))
    }

    static func label(for type: String) -> String {
        switch type {
        case "PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion": return "display"
        case "PreventUserIdleSystemSleep", "NoIdleSleepAssertion": return "idle system"
        case "PreventSystemSleep": return "system sleep"
        case "PreventDiskIdle": return "disk idle"
        default: return type
        }
    }

    /// `ps` etime: [[dd-]hh:]mm:ss → "20d 19h", "3h 12m", "4m".
    static func formatElapsed(_ etime: String) -> String {
        var days = 0
        var rest = Substring(etime)
        if let dash = rest.firstIndex(of: "-") {
            days = Int(rest[..<dash]) ?? 0
            rest = rest[rest.index(after: dash)...]
        }
        let parts = rest.split(separator: ":").compactMap { Int($0) }
        let (h, m) = parts.count == 3 ? (parts[0], parts[1]) : (0, parts.first ?? 0)
        if days > 0 { return "\(days)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
