import AppKit
import Combine
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

    var keepDisplayOn: Bool {
        get { UserDefaults.standard.object(forKey: "keepDisplayOn") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "keepDisplayOn") }
    }

    func keepAwake(seconds: Int?) {
        KeepAwake.start(seconds: seconds, display: keepDisplayOn)
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

    func stopAll() { _ = KeepAwake.stop(snapshot.caffeinate.map(\.pid)) }

    func displayOff() { _ = Shell.run("/usr/bin/pmset", ["displaysleepnow"]) }

    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    func setLaunchAtLogin(_ on: Bool) {
        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        syncLaunchAtLogin()
    }

    /// The login item can also change in System Settings, so re-read it whenever the popover opens.
    func syncLaunchAtLogin() { launchAtLogin = SMAppService.mainApp.status == .enabled }
}

private let shortLabels = ["display": "display", "idle system": "idle", "system sleep": "system", "disk idle": "disk"]

struct Chip: View {
    let label: String
    var body: some View {
        Text(shortLabels[label] ?? label).font(.caption2.weight(.medium))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
            .foregroundStyle(Color.accentColor)
            .help("Prevents \(label.hasSuffix("sleep") ? label : label + " sleep")")
    }
}

private func detail(_ h: Holder) -> String { "pid \(h.pid) · \(h.parent) · up \(h.running)" }

struct CaffeinateCard: View {
    let holder: Holder
    let onStop: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(holder.command).font(.system(.callout, design: .monospaced)).lineLimit(2).textSelection(.enabled)
                Spacer()
                Button("Stop", action: onStop).controlSize(.small)
            }
            HStack(spacing: 4) { ForEach(holder.holds, id: \.self, content: Chip.init) }
            if let start = holder.startedAt, let end = holder.endsAt, end > start {
                let total = end.timeIntervalSince(start), elapsed = Date().timeIntervalSince(start)
                // A plain bar: the system linear ProgressView draws a moving highlight that reads as busy.
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.1))
                        Capsule().fill(Color.accentColor).frame(width: g.size.width * min(max(elapsed / total, 0), 1))
                    }
                }
                .frame(height: 4)
                Text(verbatim: "\(Duration.format(seconds: Int(elapsed))) of \(Duration.format(seconds: Int(total) + 30))"
                    + " · ends \(end.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text(verbatim: "up \(holder.running) · until stopped").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(hovering ? 0.08 : 0.05)))
        .onHover { hovering = $0 }
        .help(detail(holder))
    }
}

struct OtherRow: View {
    let holder: Holder
    @State private var hovering = false

    var body: some View {
        let id = AppIdentity.of(holder)
        HStack(alignment: .top, spacing: 8) {
            Image(nsImage: id.icon).resizable().frame(width: 20, height: 20).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(id.name)
                    Spacer()
                    HStack(spacing: 4) { ForEach(holder.holds, id: \.self, content: Chip.init) }
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.07) : .clear))
        .onHover { hovering = $0 }
        .help("\(holder.command)\n\(detail(holder))")
    }
}

struct MenuContent: View {
    @ObservedObject var model: Model
    @State private var showOthers = false
    @State private var showOthersInfo = false
    @AppStorage("keepDisplayOn") private var keepDisplayOn = true

    var body: some View {
        let s = model.snapshot
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(nsImage: MenuBarIcon.image(for: s.state)).resizable().frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(s)).font(.headline)
                    Text(verbatim: subtitle(s)).font(.caption).foregroundStyle(.secondary)
                }
            }

            ForEach(s.caffeinate) { h in CaffeinateCard(holder: h) { model.stop(h) } }

            HStack(spacing: 6) {
                Text("Keep awake").foregroundStyle(.secondary)
                Spacer()
                Button("1h") { model.keepAwake(seconds: 3600) }
                Button("4h") { model.keepAwake(seconds: 4 * 3600) }
                Button("∞") { model.keepAwake(seconds: nil) }
                    .help("Until stopped")
                Divider().frame(height: 16)
                Toggle("Keep display on", isOn: $keepDisplayOn)
            }

            if !s.others.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Button {
                        showOthers.toggle()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .rotationEffect(.degrees(showOthers ? 90 : 0))
                            Text("Other apps (\(s.others.count))")
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button { showOthersInfo.toggle() } label: { Image(systemName: "info.circle") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .popover(isPresented: $showOthersInfo, arrowEdge: .bottom) {
                            Text("Apps and system services other than caffeinate that are also preventing sleep.")
                                .font(.callout)
                                .frame(width: 240, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(10)
                        }
                    Color.clear.contentShape(Rectangle()).onTapGesture { showOthers.toggle() }
                }
                if showOthers {
                    VStack(alignment: .leading, spacing: 2) { ForEach(s.others) { OtherRow(holder: $0) } }
                }
            }

            Divider()
            HStack {
                Button("Turn display off now", action: model.displayOff)
                Spacer()
                Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
            }
            HStack {
                Text("Updated \(s.updated.formatted(date: .omitted, time: .standard))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                Spacer()
                Button("Refresh") { model.refresh() }
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 400)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func title(_ s: Snapshot) -> String {
        switch s.state {
        case .caffeinate:
            return s.caffeinate.contains { $0.holds.contains("display") } ? "Mac and display awake" : "Mac awake, display can sleep"
        case .other:
            let names = Array(Set(s.others.map { AppIdentity.of($0).name })).sorted()
            return names.count == 1 ? "\(names[0]) is keeping the Mac awake" : "\(names.count) apps are keeping the Mac awake"
        case .idle:
            return "Mac can sleep"
        }
    }

    private func subtitle(_ s: Snapshot) -> String {
        switch s.state {
        case .caffeinate:
            guard s.caffeinate.count == 1, let h = s.caffeinate.first else { return "\(s.caffeinate.count) caffeinate processes" }
            return "caffeinate · \(h.parent) · " + (h.endsIn.map { "ends in \($0)" } ?? "until stopped")
        case .other: return "caffeinate isn't running"
        case .idle: return "Nothing is preventing sleep"
        }
    }
}

/// A status item rather than `MenuBarExtra`, which can't tell a right click from a left one.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = Model()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var sub: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let button = statusItem.button!
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        sub = model.$snapshot.sink { s in button.image = MenuBarIcon.image(for: s.state, text: s.countdown) }

        let host = NSHostingController(rootView: MenuContent(model: model))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = false
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            popover.performClose(nil)
            statusItem.menu = shortcuts()
            sender.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            model.refresh()
            model.syncLaunchAtLogin()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    private func shortcuts() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Keep awake for 1 hour", key: "1") { [model] in model.keepAwake(seconds: 3600) }
        menu.addItem(withTitle: "Keep awake for 4 hours", key: "4") { [model] in model.keepAwake(seconds: 4 * 3600) }
        menu.addItem(withTitle: "Keep awake until stopped", key: "0") { [model] in model.keepAwake(seconds: nil) }
        menu.addItem(withTitle: "Keep display on", key: "d") { [model] in model.keepDisplayOn.toggle() }
            .state = model.keepDisplayOn ? .on : .off
        let running = model.snapshot.caffeinate.count
        if running > 0 {
            menu.addItem(.separator())
            menu.addItem(withTitle: running == 1 ? "Stop caffeinate" : "Stop all \(running) caffeinate", key: "s") { [model] in model.stopAll() }
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Turn display off now", key: "") { [model] in model.displayOff() }
        menu.addItem(withTitle: "Quit", key: "q") { NSApp.terminate(nil) }
        return menu
    }
}

private final class ActionItem: NSMenuItem {
    private let handler: () -> Void
    init(_ title: String, key: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func run() { handler() }
}

private extension NSMenu {
    @discardableResult
    func addItem(withTitle title: String, key: String, handler: @escaping () -> Void) -> NSMenuItem {
        let item = ActionItem(title, key: key, handler: handler)
        addItem(item)
        return item
    }
}

enum CaffeineWatchApp {
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        NSApplication.shared.run()
    }
}
