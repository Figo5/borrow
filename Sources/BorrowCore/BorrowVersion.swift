import Foundation

/// Shared by the source-built tools and the packaged application.
public enum BorrowVersion {
    public static let current: String = {
        guard let url = Bundle.module.url(forResource: "VERSION", withExtension: nil),
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            return "development"
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }()
}
