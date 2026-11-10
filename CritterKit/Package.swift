// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CritterKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "CritterKit", targets: ["CritterKit"])],
    targets: [
        .target(name: "CritterKit"),
        .testTarget(name: "CritterKitTests", dependencies: ["CritterKit"]),
    ]
)
