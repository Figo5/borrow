import Foundation
import Testing
@testable import BorrowCore

@Test(arguments: ["MacOS", "Helpers"], ["VERSION", "Contents/Resources/VERSION"])
func packagedVersionDoesNotDependOnTheSPMResourceSearchPath(executableFolder: String, resourceFile: String) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let contents = root.appendingPathComponent("Preview.app/Contents")
    let bundle = contents.appendingPathComponent("Resources/Borrow_BorrowCore.bundle")
    let versionFile = bundle.appendingPathComponent(resourceFile)
    try FileManager.default.createDirectory(at: versionFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "0.3.0\n".write(to: versionFile, atomically: true, encoding: .utf8)
    var fallbackUsed = false
    let version = BorrowVersion.resolve(executableURL: contents.appendingPathComponent("\(executableFolder)/borrow")) {
        fallbackUsed = true
        return "unavailable-generated-accessor"
    }
    #expect(version == "0.3.0")
    #expect(!fallbackUsed)
}

@Test func incompleteAppDoesNotFallBackToAFatalGeneratedAccessor() {
    var fallbackUsed = false
    let version = BorrowVersion.resolve(executableURL: URL(fileURLWithPath: "/missing/Preview.app/Contents/Helpers/borrow")) {
        fallbackUsed = true
        return "unexpected"
    }
    #expect(version == "development")
    #expect(!fallbackUsed)
}

@Test func sourceBuiltVersionUsesTheSPMResources() {
    var fallbackUsed = false
    let version = BorrowVersion.resolve(executableURL: URL(fileURLWithPath: "/build/debug/borrow")) {
        fallbackUsed = true
        return "source-version"
    }
    #expect(version == "source-version")
    #expect(fallbackUsed)
    #expect(BorrowVersion.current != "development")
}
