import BorrowCore
import Darwin
import Foundation

enum UsageError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

@main
struct BorrowCLI {
    @MainActor static func main() async {
        do { try await execute(Array(CommandLine.arguments.dropFirst())) }
        catch {
            FileHandle.standardError.write(Data("borrow: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    @MainActor static func execute(_ arguments: [String]) async throws {
        guard let command = arguments.first else { print(help); return }
        if command == "--help" || command == "help" { print(help); return }
        if command == "worker" {
            signal(SIGTERM, SIG_DFL); signal(SIGINT, SIG_DFL)
            guard arguments.count == 5, let id = UUID(uuidString: arguments[1]), let seconds = Int(arguments[2]), (1...86400).contains(seconds) else {
                throw UsageError.invalid("Invalid internal worker arguments")
            }
            let url = URL(fileURLWithPath: arguments[3])
            guard arguments[4] == "--internal" else { throw UsageError.invalid("Worker is internal") }
            for tick in 0...seconds {
                try RecordingStore.encoder().encode(WorkerProof(runID: id, heartbeat: tick, completed: tick == seconds))
                    .write(to: url, options: .atomic)
                if tick < seconds { try await Task.sleep(for: .seconds(1)) }
            }
            return
        }
        guard command == "rehearse" || command == "run" else { throw UsageError.invalid(help) }
        var seconds = command == "rehearse" ? 120 : 3600
        var network = false
        var root = RecordingStore.defaultRoot
        var task: [String] = []
        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--": task = Array(arguments.dropFirst(index + 1)); index = arguments.count; continue
            case "--network": network = true
            case "--duration", "--timeout":
                index += 1
                let maximum = command == "rehearse" ? 600 : 3600
                guard index < arguments.count, let value = Int(arguments[index]), (3...maximum).contains(value) else {
                    throw UsageError.invalid("Duration must be 3…\(maximum) seconds in this prototype")
                }
                seconds = value
            case "--output":
                index += 1
                guard index < arguments.count else { throw UsageError.invalid("--output needs a directory") }
                root = URL(fileURLWithPath: arguments[index], isDirectory: true)
            default: throw UsageError.invalid("Unknown option \(arguments[index])")
            }
            index += 1
        }
        if command == "run" && task.isEmpty { throw UsageError.invalid("run requires -- /absolute/path/to/executable [args]") }
        if let executable = task.first, !executable.hasPrefix("/") { throw UsageError.invalid("Use an absolute executable path") }
        let record = RunRecord(kind: command == "run" ? .command : .rehearsal,
            title: task.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Closed-lid rehearsal",
            seconds: seconds, networkEnabled: network)
        let directory = root.appendingPathComponent(record.id.uuidString, isDirectory: true)
        let proof = directory.appendingPathComponent("worker.json")
        let recorder = Recorder(record: record, directory: directory)
        signal(SIGTERM, SIG_IGN); signal(SIGINT, SIG_IGN)
        let signals = [SIGTERM, SIGINT].map { number -> DispatchSourceSignal in
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { recorder.cancelled = true }; source.resume(); return source
        }
        defer { signals.forEach { $0.cancel() } }
        print("Recording: \(directory.path)")
        let result = try await recorder.run(
            executable: URL(fileURLWithPath: task.first ?? CommandLine.arguments[0]).standardizedFileURL,
            arguments: command == "run" ? Array(task.dropFirst()) : ["worker", record.id.uuidString, String(seconds), proof.path, "--internal"],
            proofURL: command == "run" ? nil : proof)
        print("\(result.status.rawValue). Report: \(directory.appendingPathComponent("report.md").path)")
        if result.status == .cancelled { exit(130) }
        if result.status == .timedOut { exit(124) }
        if result.status == .interrupted { exit(1) }
        if let code = result.exitCode, code != 0 { exit(code > 0 && code < 126 ? code : 1) }
    }

    static let help = """
    Borrow 0.1 — rehearse and record unattended local work

      borrow rehearse [--duration 120] [--network] [--output DIRECTORY]
      borrow run [--timeout 3600] [--network] [--output DIRECTORY] -- /absolute/executable [args]

    --network contacts Apple's connectivity endpoint. It does not probe your model provider.
    Reports are local. Command arguments and output are not saved; foreground output passes through.
    No sleep settings are changed. Use your existing keep-awake setup for a closed-lid rehearsal.
    Cancellation/timeouts terminate only the owned foreground process, not descendants.
    """
}
