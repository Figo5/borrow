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
    var duration = 120
    var error: String?
    private var process: Process?
    private var launchLog: FileHandle?
    private var runsBeforeLaunch: Set<UUID>?
    var selected: RunRecord? { runs.first { $0.id == selectedID } ?? runs.first }
    var isRunning: Bool { process?.isRunning == true }

    func refresh() {
        do {
            let root = RecordingStore.defaultRoot
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let folders = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            runs = folders.compactMap { try? RecordingStore.read(from: $0) }.sorted { $0.startedAt > $1.startedAt }
            if let previous = runsBeforeLaunch {
                if let created = runs.first(where: { !previous.contains($0.id) }) {
                    selectedID = created.id; runsBeforeLaunch = nil
                }
            } else if selectedID == nil { selectedID = runs.first?.id }
            if let process, !process.isRunning {
                if process.terminationStatus != 0 && process.terminationStatus != 130 {
                    error = "Recorder exited \(process.terminationStatus). Check the latest recording and recorder.log."
                }
                self.process = nil
                runsBeforeLaunch = nil
                try? launchLog?.close(); launchLog = nil
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
            child.arguments = arguments + (networkEnabled ? ["--network"] : [])
            child.standardOutput = launchLog; child.standardError = launchLog
            try child.run(); process = child
            runsBeforeLaunch = Set(runs.map(\.id)); selectedID = nil
        } catch { self.error = error.localizedDescription }
    }

    func cancel() { if let process, process.isRunning { process.terminate() } }
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
            if model.isRunning { Button("Stop recording") { model.cancel() } }
            Divider()
            Text("Borrow does not prevent sleep.")
            Button("Quit Borrow") { NSApplication.shared.terminate(nil) }
        }
    }
}

final class BorrowDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
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
                Text("Local prototype · 0.2.1\nNo sleep settings changed.")
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
                            Text("Borrow checks for real work across a closed-lid interval. Start a short rehearsal, close the lid on a ventilated desk, then reopen it to inspect what happened.")
                                .foregroundStyle(.secondary)
                            Text("Use your existing keep-awake setup. Without one, macOS may sleep; Borrow records that outcome after wake.")
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
            Text("Rehearse the lid close. Review the evidence.").font(.title3).foregroundStyle(.secondary)
            HStack {
                Picker("Length", selection: $model.duration) {
                    Text("30 seconds").tag(30); Text("2 minutes").tag(120); Text("5 minutes").tag(300)
                }.frame(width: 210).disabled(model.isRunning)
                Spacer()
                if model.isRunning {
                    ProgressView().controlSize(.small)
                    Button("Stop recording") { model.cancel() }
                } else {
                    Button("Observe Codex…") { model.observeCodex() }.controlSize(.large)
                    Button("Start rehearsal", systemImage: "play.fill") { model.start() }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                }
            }
            Toggle("Include connectivity checks", isOn: $model.networkEnabled).disabled(model.isRunning)
            Text("Optional checks contact captive.apple.com. Your code and prompts are never sent. The probe does not test your agent’s own connection.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
        }
    }

    private func recording(_ run: RunRecord) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(run.title).font(.title2.weight(.semibold))
                Spacer()
                Text(run.statusLabel).font(.callout.weight(.medium)).foregroundStyle(.secondary)
            }
            if run.status == .running {
                let age = Date().timeIntervalSince(run.observations.last?.time ?? run.startedAt)
                Label(age > 10 ? "Recorder has not sampled recently; its condition is unknown." : run.kind == .codexSession ? "Observing new Codex events. Borrow does not control the agent." : "Recording. Close the lid, wait, then reopen to review.",
                      systemImage: age > 10 ? "questionmark.circle" : "record.circle")
                    .foregroundStyle(accent)
            }
            HStack(spacing: 32) {
                if run.kind == .codexSession {
                    metric("New agent events", value: "\(run.agent?.activityCount ?? 0)")
                    metric("Events while closed", value: "\(run.closedLidAgentEvents)")
                } else {
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
    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 26, weight: .medium, design: .rounded)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
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
