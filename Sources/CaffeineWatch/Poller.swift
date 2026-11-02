import Foundation

struct Holder: Identifiable, Hashable {
    var id: Int32 { pid }
    let pid: Int32
    let processName: String
    let command: String
    let parent: String
    let startedAt: Date?
    let holds: [String]
    let endsAt: Date?

    var isCaffeinate: Bool { processName == "caffeinate" }
    var running: String { startedAt.map { Duration.format(seconds: Int(Date().timeIntervalSince($0))) } ?? "?" }
    var endsIn: String? { endsAt.map(Duration.remaining) }
}

enum WakeState { case caffeinate, other, idle }

struct Snapshot {
    var holders: [Holder] = []
    var updated = Date()

    var caffeinate: [Holder] { holders.filter(\.isCaffeinate) }
    var others: [Holder] { holders.filter { !$0.isCaffeinate } }
    /// Time left when every running caffeinate has a timeout; nil if any runs until stopped.
    var countdown: String? {
        let ends = caffeinate.map(\.endsAt)
        guard !ends.isEmpty, !ends.contains(where: { $0 == nil }) else { return nil }
        return ends.compactMap { $0 }.max().map(Duration.remaining)
    }
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

/// Builds snapshots from power assertions. `ps` and `tmux` only run when a holder pid appears
/// for the first time; afterwards a poll is a single IOKit call.
final class Poller {
    private static let tmuxPaths = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]

    private struct Info { let processName: String; let command: String; let parent: String; let startedAt: Date? }
    private var cache: [Int32: Info] = [:]

    static func snapshot() -> Snapshot { Poller().snapshot() }

    func snapshot() -> Snapshot {
        let byPid = Dictionary(grouping: Assertions.current().filter(Assertions.preventsSleep), by: \.pid)
        cache = cache.filter { pid, info in byPid[pid]?.first?.processName == info.processName }
        let newPids = byPid.keys.filter { cache[$0] == nil }
        if !newPids.isEmpty { describe(newPids, names: byPid.mapValues { $0[0].processName }) }

        let holders = byPid.map { pid, list -> Holder in
            let info = cache[pid]
            return Holder(
                pid: pid,
                processName: list[0].processName,
                command: info?.command ?? list[0].processName,
                parent: info?.parent ?? "?",
                startedAt: info?.startedAt,
                holds: Array(Set(list.map { Assertions.label(for: $0.type) })).sorted(),
                endsAt: list.compactMap(\.endsAt).max()
            )
        }
        .sorted { ($0.isCaffeinate ? 0 : 1, $0.pid) < ($1.isCaffeinate ? 0 : 1, $1.pid) }
        return Snapshot(holders: holders)
    }

    private func describe(_ pids: [Int32], names: [Int32: String]) {
        // pid → (ppid, comm) for the whole table, to walk ancestors.
        var table: [Int32: (ppid: Int32, comm: String)] = [:]
        for row in Shell.run("/bin/ps", ["-axo", "pid=,ppid=,comm="]).split(separator: "\n") {
            let f = row.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard f.count == 3, let pid = Int32(f[0]), let ppid = Int32(f[1]) else { continue }
            table[pid] = (ppid, String(f[2]))
        }

        var detail: [Int32: (etime: String, args: String)] = [:]
        let pidList = pids.map(String.init).joined(separator: ",")
        for row in Shell.run("/bin/ps", ["-o", "pid=,etime=,args=", "-p", pidList]).split(separator: "\n") {
            let f = row.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard f.count == 3, let pid = Int32(f[0]) else { continue }
            detail[pid] = (String(f[1]), String(f[2]))
        }

        var tmuxPanes: [Int32: String] = [:]
        if let tmux = Self.tmuxPaths.first(where: FileManager.default.isExecutableFile) {
            for row in Shell.run(tmux, ["list-panes", "-a", "-F", "#{pane_pid} #{session_name}"]).split(separator: "\n") {
                let f = row.split(separator: " ", maxSplits: 1)
                if f.count == 2, let pid = Int32(f[0]) { tmuxPanes[pid] = String(f[1]) }
            }
        }

        let now = Date()
        for pid in pids {
            let d = detail[pid]
            cache[pid] = Info(
                processName: names[pid] ?? "?",
                command: d?.args ?? names[pid] ?? "?",
                parent: Self.parentDescription(pid: pid, table: table, tmuxPanes: tmuxPanes),
                startedAt: d.map { now.addingTimeInterval(-Double(Duration.seconds(etime: $0.etime))) }
            )
        }
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
