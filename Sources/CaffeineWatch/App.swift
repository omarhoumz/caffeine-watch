import AppKit
import ServiceManagement
import SwiftUI

final class Model: ObservableObject {
    @Published var snapshot = Snapshot()
    private var timer: Timer?
    private let queue = DispatchQueue(label: "caffeine-watch.poll")
    private let poller = Poller()
    /// Exit watchers on caffeinate processes, so a stop shows up immediately rather than on the next poll.
    private var exitWatchers: [Int32: DispatchSourceProcess] = [:]

    init() {
        refresh()
        // powerd posts no usable change notification for assertions, so new holders are found by polling.
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        queue.async {
            let s = self.poller.snapshot()
            DispatchQueue.main.async {
                self.snapshot = s
                self.watchExits(of: s.caffeinate.map(\.pid))
            }
        }
    }

    private func watchExits(of pids: [Int32]) {
        for (pid, source) in exitWatchers where !pids.contains(pid) {
            source.cancel()
            exitWatchers[pid] = nil
        }
        for pid in pids where exitWatchers[pid] == nil {
            let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
            source.setEventHandler { [weak self] in self?.refresh() }
            source.resume()
            exitWatchers[pid] = source
        }
    }

    func keepAwake(seconds: Int?, display: Bool) {
        KeepAwake.start(seconds: seconds, display: display)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.refresh() }
    }

    func stop(_ h: Holder) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Stop \(h.processName) (pid \(h.pid))?"
        alert.informativeText = "\(h.command)\n\(h.parent)"
        alert.addButton(withTitle: "Stop")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = KeepAwake.stop([h.pid])
    }
}

struct HolderView: View {
    let holder: Holder
    let onStop: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(holder.command).font(.system(.body, design: .monospaced)).lineLimit(2).textSelection(.enabled)
                Spacer()
                if let onStop { Button("Stop", action: onStop).controlSize(.small) }
            }
            Text(verbatim: "pid \(holder.pid) · \(holder.parent) · up \(holder.running)"
                + (holder.endsIn.map { " · ends in \($0)" } ?? ""))
                .font(.caption).foregroundStyle(.secondary)
            Text("prevents: " + holder.holds.joined(separator: ", "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct MenuContent: View {
    @ObservedObject var model: Model
    @State private var showOthers = false
    @AppStorage("keepDisplayOn") private var keepDisplayOn = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        let s = model.snapshot
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(nsImage: MenuBarIcon.image(for: s.state))
                Text(headline(s)).font(.headline)
            }

            if !s.caffeinate.isEmpty {
                ForEach(s.caffeinate) { h in HolderView(holder: h) { model.stop(h) } }
            }

            if !s.others.isEmpty {
                Divider()
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showOthers.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(showOthers ? 90 : 0))
                        Text("Other apps (\(s.others.count))")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showOthers {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(s.others) { h in HolderView(holder: h, onStop: nil) }
                    }
                }
            }

            Divider()
            HStack {
                Menu("Keep awake") {
                    Button("1 hour") { model.keepAwake(seconds: 3600, display: keepDisplayOn) }
                    Button("4 hours") { model.keepAwake(seconds: 4 * 3600, display: keepDisplayOn) }
                    Button("Until stopped") { model.keepAwake(seconds: nil, display: keepDisplayOn) }
                }
                .fixedSize()
                Toggle("Keep display on", isOn: $keepDisplayOn)
                Spacer()
            }
            HStack {
                Button("Turn display off now") { _ = Shell.run("/usr/bin/pmset", ["displaysleepnow"]) }
                Spacer()
                Button("Refresh") { model.refresh() }
            }
            HStack {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { on in
                        do {
                            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            Text("Updated \(s.updated.formatted(date: .omitted, time: .standard))")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(width: 420)
    }

    private func headline(_ s: Snapshot) -> String {
        switch s.state {
        case .caffeinate: return "caffeinate is keeping the Mac awake"
        case .other: return "Another app is preventing sleep"
        case .idle: return "Nothing is preventing sleep"
        }
    }
}

struct CaffeineWatchApp: App {
    @StateObject private var model = Model()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: model.snapshot.state))
            if let left = model.snapshot.countdown { Text(left) }
        }
        .menuBarExtraStyle(.window)
    }
}
