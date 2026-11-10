// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Borrow",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BorrowCore", targets: ["BorrowCore"]),
        .executable(name: "borrow", targets: ["BorrowCLI"]),
        .executable(name: "BorrowApp", targets: ["BorrowApp"])
    ],
    targets: [
        .target(name: "BorrowCore"),
        .executableTarget(name: "BorrowCLI", dependencies: ["BorrowCore"]),
        .executableTarget(name: "BorrowApp", dependencies: ["BorrowCore"]),
        .testTarget(name: "BorrowCoreTests", dependencies: ["BorrowCore"], resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v5]
)
