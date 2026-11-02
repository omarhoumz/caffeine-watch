import Foundation

func printHolder(_ h: Holder) {
    print("  \(h.command)")
    print("    pid \(h.pid) · \(h.parent) · up \(h.running)")
    print("    prevents: \(h.holds.joined(separator: ", "))")
}

let args = CommandLine.arguments.dropFirst()

// `check`: silent, for scripts. Exit 0 when caffeinate is running, 1 otherwise.
if args.first == "check" {
    exit(Poller.snapshot().state == .caffeinate ? 0 : 1)
}

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
    exit(0)
}

CaffeineWatchApp.main()
