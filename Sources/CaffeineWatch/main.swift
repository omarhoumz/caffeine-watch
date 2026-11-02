import Foundation

if CommandLine.arguments.contains("--dump") {
    let s = Poller.snapshot()
    print("state: \(s.state)")
    for h in s.holders {
        print("\(h.pid)\t\(h.processName)\t\(h.command)\t\(h.parent)\tup \(h.running)\t[\(h.holds.joined(separator: ", "))]")
    }
    exit(0)
}

CaffeineWatchApp.main()
