import Foundation

struct Holder: Identifiable, Hashable {
    var id: Int32 { pid }
    let pid: Int32
    let processName: String
    let command: String
    let parent: String
    let running: String
    let holds: [String]
    let endsIn: String?

    var isCaffeinate: Bool { processName == "caffeinate" }
}

enum WakeState { case caffeinate, other, idle }

struct Snapshot {
    var holders: [Holder] = []
    var updated = Date()

    var caffeinate: [Holder] { holders.filter(\.isCaffeinate) }
    var others: [Holder] { holders.filter { !$0.isCaffeinate } }
    var state: WakeState {
        if !caffeinate.isEmpty { return .caffeinate }
        return others.isEmpty ? .idle : .other
    }
}

enum Shell {
    static func run(_ path: String, _ args: [String]) -> String {
        guard FileManager.default.isExecutableFile(atPath: path) else { return "" }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}

enum Poller {
    private static let tmuxPaths = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]

    static func snapshot() -> Snapshot {
        let assertions = Assertions.current().filter(Assertions.preventsSleep)
        let byPid = Dictionary(grouping: assertions, by: \.pid)
        guard !byPid.isEmpty else { return Snapshot() }

        // pid → (ppid, comm) for the whole table, to walk ancestors.
        var table: [Int32: (ppid: Int32, comm: String)] = [:]
        for row in Shell.run("/bin/ps", ["-axo", "pid=,ppid=,comm="]).split(separator: "\n") {
            let f = row.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard f.count == 3, let pid = Int32(f[0]), let ppid = Int32(f[1]) else { continue }
            table[pid] = (ppid, String(f[2]))
        }

        var detail: [Int32: (etime: String, args: String)] = [:]
        let pidList = byPid.keys.map(String.init).joined(separator: ",")
        for row in Shell.run("/bin/ps", ["-o", "pid=,etime=,args=", "-p", pidList]).split(separator: "\n") {
            let f = row.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard f.count == 3, let pid = Int32(f[0]) else { continue }
            detail[pid] = (String(f[1]), String(f[2]))
        }

        var tmuxPanes: [Int32: String] = [:]
        if let tmux = tmuxPaths.first(where: FileManager.default.isExecutableFile) {
            for row in Shell.run(tmux, ["list-panes", "-a", "-F", "#{pane_pid} #{session_name}"]).split(separator: "\n") {
                let f = row.split(separator: " ", maxSplits: 1)
                if f.count == 2, let pid = Int32(f[0]) { tmuxPanes[pid] = String(f[1]) }
            }
        }

        let holders = byPid.map { pid, list -> Holder in
            let d = detail[pid]
            return Holder(
                pid: pid,
                processName: list[0].processName,
                command: d?.args ?? list[0].processName,
                parent: parentDescription(pid: pid, table: table, tmuxPanes: tmuxPanes),
                running: d.map { Duration.format(seconds: Duration.seconds(etime: $0.etime)) } ?? "?",
                holds: Array(Set(list.map { Assertions.label(for: $0.type) })).sorted(),
                endsIn: list.compactMap(\.timeLeft).max().map { Duration.format(seconds: Int($0)) }
            )
        }
        .sorted { ($0.isCaffeinate ? 0 : 1, $0.pid) < ($1.isCaffeinate ? 0 : 1, $1.pid) }
        return Snapshot(holders: holders)
    }

    /// Prefers the tmux session owning the process (or an ancestor); else the direct parent.
    private static func parentDescription(pid: Int32, table: [Int32: (ppid: Int32, comm: String)], tmuxPanes: [Int32: String]) -> String {
        var cur: Int32? = pid
        var hops = 0
        while let p = cur, p > 1, hops < 32 {
            if let session = tmuxPanes[p] { return "tmux session \"\(session)\"" }
            cur = table[p]?.ppid
            hops += 1
        }
        guard let ppid = table[pid]?.ppid else { return "?" }
        let comm = table[ppid].map { ($0.comm as NSString).lastPathComponent } ?? "?"
        return "\(comm) (\(ppid))"
    }
}
