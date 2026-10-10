// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadAlongKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "ReadAlongKit", targets: ["ReadAlongKit"])],
    targets: [
        .target(name: "ReadAlongKit"),
        .testTarget(name: "ReadAlongKitTests", dependencies: ["ReadAlongKit"])
    ]
)
