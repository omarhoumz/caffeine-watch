import Foundation
import IOKit.pwr_mgt

struct Assertion: Hashable {
    let pid: Int32
    let processName: String
    let type: String
    let name: String
    let timeLeft: TimeInterval?
}

enum Assertions {
    /// Current power assertions, from the same source `pmset -g assertions` reads.
    static func current() -> [Assertion] {
        var ref: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&ref) == kIOReturnSuccess,
              let byPid = ref?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [] }
        return byPid.flatMap { pid, list in
            list.compactMap { a -> Assertion? in
                guard (a["AssertLevel"] as? Int ?? 0) > 0, let type = a["AssertType"] as? String else { return nil }
                return Assertion(
                    pid: pid.int32Value,
                    processName: a["Process Name"] as? String ?? "?",
                    type: type,
                    name: a["AssertName"] as? String ?? "",
                    timeLeft: a["AssertTimeoutTimeLeft"] as? TimeInterval
                )
            }
        }
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
}

enum Duration {
    /// "20d 19h", "3h 12m", "4m".
    static func format(seconds: Int) -> String {
        let d = seconds / 86400, h = seconds % 86400 / 3600, m = seconds % 3600 / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// `ps` etime: [[dd-]hh:]mm:ss.
    static func seconds(etime: String) -> Int {
        var days = 0
        var rest = Substring(etime)
        if let dash = rest.firstIndex(of: "-") {
            days = Int(rest[..<dash]) ?? 0
            rest = rest[rest.index(after: dash)...]
        }
        let parts = rest.split(separator: ":").compactMap { Int($0) }
        return days * 86400 + parts.reduce(0) { $0 * 60 + $1 }
    }

    /// "90", "45m", "2h", "1h30m", "1d" → seconds. Bare numbers are seconds, as in `caffeinate -t`.
    static func parse(_ s: String) -> Int? {
        if let n = Int(s) { return n }
        var total = 0, num = ""
        for c in s.lowercased() {
            if c.isNumber { num.append(c); continue }
            guard let n = Int(num) else { return nil }
            switch c {
            case "d": total += n * 86400
            case "h": total += n * 3600
            case "m": total += n * 60
            case "s": total += n
            default: return nil
            }
            num = ""
        }
        return num.isEmpty && total > 0 ? total : nil
    }
}
