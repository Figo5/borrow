import Foundation

/// Shared by the source-built tools and the packaged application.
public enum BorrowVersion {
    public static let current: String = resolve(
        executableURL: Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
    ) {
        readVersion(at: Bundle.module.url(forResource: "VERSION", withExtension: nil)) ?? "development"
    }

    static func resolve(executableURL: URL, sourceVersion: () -> String) -> String {
        let executableFolder = executableURL.deletingLastPathComponent()
        let contents = executableFolder.deletingLastPathComponent()
        guard ["MacOS", "Helpers"].contains(executableFolder.lastPathComponent),
              contents.lastPathComponent == "Contents",
              contents.deletingLastPathComponent().pathExtension.lowercased() == "app" else {
            return sourceVersion()
        }
        // Older SwiftPM accessors search beside the executable or in a removed build directory.
        // Packaged binaries use the app's stable resource location without evaluating that accessor.
        let bundle = contents.appendingPathComponent("Resources/Borrow_BorrowCore.bundle")
        return readVersion(at: bundle.appendingPathComponent("VERSION"))
            ?? readVersion(at: bundle.appendingPathComponent("Contents/Resources/VERSION"))
            ?? "development"
    }

    private static func readVersion(at url: URL?) -> String? {
        guard let url, let value = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
