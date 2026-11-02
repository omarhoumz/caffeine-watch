import Foundation

let usage = """
usage: caffeine-watch [command]

  status                     show what is keeping the Mac awake (the default)
  check                      exit 0 if caffeinate is running, 1 otherwise; prints nothing
  start [duration] [--display]
                             start caffeinate (-ims, plus -d with --display) in the background;
                             duration like 90, 45m, 2h, 1h30m; omitted = until stopped
  stop [pid]                 stop one caffeinate, or all of them
  help                       show this
"""

func printHolder(_ h: Holder) {
    print("  \(h.command)")
    var line = "    pid \(h.pid) · \(h.parent) · up \(h.running)"
    if let end = h.endsIn { line += " · ends in \(end)" }
    print(line)
    print("    prevents: \(h.holds.joined(separator: ", "))")
}

func printStatus() {
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
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}

var args = Array(CommandLine.arguments.dropFirst())
if args.contains("--dump") { args = ["status"] }

switch args.first {
case "status":
    printStatus()
case "check":
    exit(Poller.snapshot().state == .caffeinate ? 0 : 1)
case "start":
    let display = args.contains("--display")
    let rest = args.dropFirst().filter { $0 != "--display" }
    var seconds: Int?
    if let d = rest.first {
        guard let s = Duration.parse(d), s > 0 else { fail("bad duration: \(d)\n\n\(usage)") }
        seconds = s
    }
    guard let pid = KeepAwake.start(seconds: seconds, display: display) else { fail("could not start caffeinate") }
    let span = seconds.map { "for " + Duration.format(seconds: $0) } ?? "until stopped"
    print("started caffeinate \(display ? "-dims" : "-ims") (pid \(pid)) \(span)")
case "stop":
    let running = Poller.snapshot().caffeinate.map(\.pid)
    var targets = running
    if let p = args.dropFirst().first {
        guard let pid = Int32(p), running.contains(pid) else { fail("no caffeinate with pid \(p)") }
        targets = [pid]
    }
    if targets.isEmpty { print("no caffeinate running") }
    for pid in KeepAwake.stop(targets) { print("stopped caffeinate (pid \(pid))") }
case "help", "-h", "--help":
    print(usage)
case .some(let other):
    fail("unknown command: \(other)\n\n\(usage)")
case nil:
    // The app bundle launches the binary bare; the `caffeine-watch` symlink means someone typed the CLI.
    if (CommandLine.arguments[0] as NSString).lastPathComponent == "caffeine-watch" { printStatus() } else { CaffeineWatchApp.main() }
}
