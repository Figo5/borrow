import AppKit
import BorrowCore
import Darwin
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor @Observable
final class BorrowModel {
    var runs: [RunRecord] = []
    var selectedID: UUID?
    var networkEnabled = false
    var wakeMode = WakeMode.off
    var duration = 120
    var error: String?
    var isStopping = false
    private var process: Process?
    private var launchLog: FileHandle?
    private var runsBeforeLaunch: Set<UUID>?
    private var activeRunID: UUID?
    private var stopRequestedAt: Date?
    var selected: RunRecord? { runs.first { $0.id == selectedID } ?? runs.first }
    var isRunning: Bool { process?.isRunning == true }
    func ownsRecorder(for run: RunRecord) -> Bool { isRunning && run.id == activeRunID }
    var hasOtherRecentRecorder: Bool {
        let now = Date()
        return runs.contains { run in
            let age = now.timeIntervalSince(run.observations.last?.time ?? run.startedAt)
            return run.status == .running && !ownsRecorder(for: run) && (0...10).contains(age)
        }
    }

    func refresh() {
        do {
            let root = RecordingStore.defaultRoot
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let folders = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            runs = folders.compactMap { try? RecordingStore.read(from: $0) }.sorted { $0.startedAt > $1.startedAt }
            if let previous = runsBeforeLaunch {
                if let created = runs.first(where: {
                    !previous.contains($0.id) && $0.recorderPID == process?.processIdentifier
                }) {
                    selectedID = created.id; activeRunID = created.id; runsBeforeLaunch = nil
                }
            } else if selectedID == nil { selectedID = runs.first?.id }
            if let process, !process.isRunning {
                if process.terminationStatus != 0 && process.terminationStatus != 130 {
                    error = "Recorder exited \(process.terminationStatus). Check the latest recording and recorder.log."
                }
                self.process = nil
                isStopping = false
                stopRequestedAt = nil
                runsBeforeLaunch = nil
                try? launchLog?.close(); launchLog = nil
            }
            if isRunning, isStopping, let stopRequestedAt, Date().timeIntervalSince(stopRequestedAt) >= 12 {
                isStopping = false
                self.stopRequestedAt = nil
                error = "The recorder has not exited yet. You can retry Stop; its bounded deadline still applies."
            }
        } catch { self.error = error.localizedDescription }
    }

    func start() {
        launch(["rehearse", "--duration", String(duration)])
    }

    func observeCodex() {
        guard !isRunning else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose one Codex session log"
        panel.message = "Borrow reads this log locally and keeps lifecycle events only. Prompts, reasoning, tool arguments and output are discarded. This experimental adapter does not infer approvals or control the agent."
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "jsonl") ?? .data]
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
        if panel.runModal() == .OK, let url = panel.url {
            launch(["observe-codex", "--session", url.path, "--timeout", String(duration)])
        }
    }

    private func launch(_ arguments: [String]) {
        guard !isRunning else { return }
        error = nil
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/borrow")
        let sibling = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("borrow")
        let cli = FileManager.default.isExecutableFile(atPath: bundled.path) ? bundled : sibling
        guard FileManager.default.isExecutableFile(atPath: cli.path) else {
            error = "The borrow recorder is missing. Build both executables or use scripts/build-app.sh."; return
        }
        do {
            let root = RecordingStore.defaultRoot
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let log = root.deletingLastPathComponent().appendingPathComponent("recorder.log")
            if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
            launchLog = try FileHandle(forWritingTo: log); try launchLog?.truncate(atOffset: 0)
            let child = Process(); child.executableURL = cli
            child.arguments = arguments + ["--wake", wakeMode.rawValue] + (networkEnabled ? ["--network"] : [])
            child.standardOutput = launchLog; child.standardError = launchLog
            try child.run(); process = child
            runsBeforeLaunch = Set(runs.map(\.id)); selectedID = nil; activeRunID = nil
        } catch {
            self.error = "Could not start the recorder. Check that Borrow is installed completely."
            try? launchLog?.close(); launchLog = nil
        }
    }

    func cancel() {
        if let process, process.isRunning {
            isStopping = true
            stopRequestedAt = Date()
            process.terminate()
        }
    }

    func stopForQuit() async -> Bool {
        cancel()
        let deadline = Date().addingTimeInterval(12)
        while isRunning && Date() < deadline {
            refresh()
            do { try await Task.sleep(for: .milliseconds(100)) }
            catch { return false }
        }
        refresh()
        guard !isRunning else {
            isStopping = false
            stopRequestedAt = nil
            error = "The recorder has not exited yet. Borrow stays open while cleanup is unverified."
            return false
        }
        guard let run = runs.first(where: { $0.id == activeRunID }) else {
            error = "The recorder ended, but its final report could not be read. Review the latest recording before quitting."
            return false
        }
        if let power = run.power, power.state != .released && power.cleanup != .nothingHeld {
            error = "The recorder ended, but release of its wake hold is unverified. Review the report before quitting."
            return false
        }
        return true
    }
    func reveal() {
        guard let run = selected else { return }
        NSWorkspace.shared.open(RecordingStore.defaultRoot.appendingPathComponent(run.id.uuidString))
    }
    func export() {
        guard let run = selected else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = "Borrow-\(run.id.uuidString.prefix(8)).md"
        panel.allowedContentTypes = [.plainText]
        if panel.runModal() == .OK, let url = panel.url {
            do { try RecordingStore.markdown(run).write(to: url, atomically: true, encoding: .utf8) }
            catch { self.error = error.localizedDescription }
        }
    }
}

@main
struct BorrowApp: App {
    @State private var model = BorrowModel()
    @NSApplicationDelegateAdaptor(BorrowDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup("Borrow") {
            BorrowWindow(model: model)
                .frame(minWidth: 900, minHeight: 650)
                .onAppear { delegate.model = model }
                .task {
                    while !Task.isCancelled {
                        model.refresh()
                        try? await Task.sleep(for: .seconds(1))
                    }
                }
        }
        .defaultSize(width: 1120, height: 780)
        MenuBarExtra("Borrow", systemImage: model.isRunning ? "circle.dotted.circle.fill" : "moon.circle") {
            Text(model.isRunning ? "Recording" : "Borrow · Ready to rehearse")
            Button("Open Borrow") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
            }
            if model.isRunning { Button(model.isStopping ? "Stopping…" : "Stop recording") { model.cancel() }.disabled(model.isStopping) }
            Divider()
            Text("Quit stops this app instance's recorder. Other recorders keep their own deadlines.")
            Button("Quit Borrow") { NSApplication.shared.terminate(nil) }
        }
    }
}

@MainActor
final class BorrowDelegate: NSObject, NSApplicationDelegate {
    var model: BorrowModel?
    private var quitPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.isRunning else { return .terminateNow }
        guard !quitPending else { return .terminateLater }
        quitPending = true
        Task { @MainActor in
            let cleanedUp = await model.stopForQuit()
            quitPending = false
            sender.reply(toApplicationShouldTerminate: cleanedUp)
        }
        return .terminateLater
    }
}

struct BorrowWindow: View {
    @Bindable var model: BorrowModel
    private let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.96, green: 0.70, blue: 0.32, alpha: 1)
            : NSColor(srgbRed: 0.59, green: 0.31, blue: 0.04, alpha: 1)
    })
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "moon.circle").font(.largeTitle).foregroundStyle(accent)
                    VStack(alignment: .leading) {
                        Text("Borrow").font(.title2.weight(.semibold))
                        Text("Know before you go.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 12).padding(.top, 16)
                Text("RECORDINGS").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 12)
                List(selection: $model.selectedID) {
                    ForEach(model.runs) { run in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(run.title).font(.headline)
                            Text(run.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption).foregroundStyle(.secondary)
                            Text(run.statusLabel).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 5).tag(run.id)
                    }
                }.listStyle(.sidebar)
                Text("Local preview · \(BorrowVersion.current)\nNo global power settings changed.")
                    .font(.caption).foregroundStyle(.secondary).padding(12)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    introduction
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red).textSelection(.enabled)
                    }
                    if let run = model.selected { recording(run) }
                    else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("A green switch isn’t a rehearsal.").font(.title2.weight(.medium))
                            Text("Start with a 30-second rehearsal in Off mode and keep the lid open. Confirm the expected result before arranging a separate lid-close test.")
                                .foregroundStyle(.secondary)
                            Text("Choose a temporary wake hold or record with it off. Experimental AC mode needs a real test on your setup. Borrow releases only its own hold when recording ends.")
                                .font(.callout).foregroundStyle(.secondary)
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                    }
                }.padding(32).frame(maxWidth: 920, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .toolbar {
                ToolbarItemGroup {
                    Button("Show files", systemImage: "folder") { model.reveal() }.disabled(model.selected == nil)
                    Button("Export report", systemImage: "square.and.arrow.up") { model.export() }.disabled(model.selected == nil)
                }
            }
        }
        .tint(accent)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Can your task keep going?").font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Borrow time for a task. Review what happened.").font(.title3).foregroundStyle(.secondary)
            HStack {
                Picker("Length", selection: $model.duration) {
                    Text("30 seconds").tag(30); Text("2 minutes").tag(120); Text("5 minutes").tag(300); Text("10 minutes").tag(600)
                }.frame(width: 210).disabled(model.isRunning)
                Spacer()
                if model.isRunning {
                    ProgressView().controlSize(.small)
                    Button(model.isStopping ? "Stopping…" : "Stop recording") { model.cancel() }.disabled(model.isStopping)
                } else {
                    Button("Observe Codex…") { model.observeCodex() }.controlSize(.large)
                    Button("Start rehearsal", systemImage: "play.fill") { model.start() }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }
            }
            WakeModePicker(mode: $model.wakeMode, disabled: model.isRunning)
            if model.hasOtherRecentRecorder {
                Text("Recent samples from another recorder are present. This window controls only the recorder it starts; each recording has its own deadline.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Toggle("Include connectivity checks", isOn: $model.networkEnabled).disabled(model.isRunning)
            Text("Optional checks contact captive.apple.com. Your code and prompts are never sent. The probe does not test your agent’s own connection.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
        }
    }

    private func recording(_ run: RunRecord) -> some View {
        let stale = run.isStale(at: Date())
        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(run.title).font(.title2.weight(.semibold))
                Spacer()
                Text(run.statusLabel).font(.callout.weight(.medium)).foregroundStyle(.secondary)
            }
            if run.status == .running {
                Label(runningDetail(for: run, stale: stale),
                      systemImage: stale ? "questionmark.circle" : "record.circle")
                    .foregroundStyle(accent)
                if !model.ownsRecorder(for: run) {
                    Text("This app instance did not start this recorder and cannot stop it. Quitting leaves it untouched; its own recording deadline still applies. The saved state may be stale.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            if let power = run.power { WakeHoldStatus(power: power, stale: stale) }
            HStack(spacing: 32) {
                switch run.kind {
                case .codexSession:
                    metric("New agent events", value: "\(run.agent?.activityCount ?? 0)")
                    metric("Events while closed", value: "\(run.closedLidAgentEvents)")
                case .command:
                    metric("Exit code",
                           value: run.exitCode.map { String($0) } ?? "—",
                           accessibilityValue: run.exitCode.map { String($0) } ?? "Not observed")
                case .rehearsal:
                    metric("Worker ticks while closed", value: "\(run.closedLidHeartbeats)")
                }
                metric("Samples", value: "\(run.observations.count)")
                metric("Last lid state", value: run.observations.last?.lidClosed.map { $0 ? "Closed" : "Open" } ?? "Unknown")
            }.padding(.vertical, 8)
            VStack(spacing: 0) {
                ForEach(run.findings) { finding in
                    FindingRow(finding: finding).padding(.vertical, 15)
                    if finding.id != run.findings.last?.id { Divider() }
                }
            }
            Divider()
            Text("What happened").font(.headline)
            if run.events.isEmpty { Text("Waiting for the first event.").foregroundStyle(.secondary) }
            ForEach(run.events.reversed()) { event in
                HStack(alignment: .top, spacing: 16) {
                    Text(event.time, format: .dateTime.hour().minute().second()).font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary).frame(width: 86, alignment: .leading)
                    Text(event.detail).font(.callout).textSelection(.enabled)
                }
            }
            Text("\(run.macOS) · This recording covers one setup and one interval. It does not certify future runs or physical safety.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
        }
    }
    private func runningDetail(for run: RunRecord, stale: Bool) -> String {
        if stale { return "Recorder snapshot is stale; its current condition is unknown." }
        switch run.kind {
        case .codexSession: return "Observing new Codex events. Borrow does not control the agent."
        case .command: return "Command recording. Waiting for the foreground process to exit; an exit status alone does not establish that the task succeeded."
        case .rehearsal: return "Rehearsal recording. Keep the lid open for your first run; review the evidence when it ends."
        }
    }
    @ViewBuilder
    private func metric(_ label: String, value: String, accessibilityValue: String? = nil) -> some View {
        let tile = VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 26, weight: .medium, design: .rounded)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        if let accessibilityValue {
            tile.accessibilityElement(children: .combine)
                .accessibilityLabel(label)
                .accessibilityValue(accessibilityValue)
        } else {
            tile
        }
    }
}

struct FindingRow: View {
    let finding: Finding
    private var icon: String {
        switch finding.state {
        case .observed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .unverified: return "questionmark.circle"
        case .skipped: return "minus.circle"
        }
    }
    private var color: Color {
        switch finding.state {
        case .observed: return .green
        case .failed: return .orange
        case .unverified, .skipped: return .secondary
        }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(finding.title).font(.headline)
                    Spacer()
                    Text(finding.state.rawValue.capitalized).font(.caption.weight(.medium)).foregroundStyle(color)
                }
                Text(finding.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.accessibilityElement(children: .combine)
    }
}
