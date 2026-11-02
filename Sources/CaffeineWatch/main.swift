import Foundation

func printHolder(_ h: Holder) {
    print("  \(h.command)")
    print("    pid \(h.pid) · \(h.parent) · up \(h.running)")
    print("    prevents: \(h.holds.joined(separator: ", "))")
}

// CLI mode: `CaffeineWatch status` (or the older `--dump`). Exit 0 when caffeinate is running, 1 otherwise.
let args = CommandLine.arguments.dropFirst()
if args.first == "status" || args.contains("--dump") {
    let s = Poller.snapshot()
    switch s.state {
    case .caffeinate: print("caffeinate is keeping the Mac awake")
    case .other: print("Another app is preventing sleep")
    case .idle: print("Nothing is preventing sleep")
    }
    s.caffeinate.forEach(printHolder)
    if !s.others.isEmpty {
        print("Other apps:")
        s.others.forEach(printHolder)
    }
    exit(s.state == .caffeinate ? 0 : 1)
}

CaffeineWatchApp.main()
