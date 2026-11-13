// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LocalShot",
  platforms: [.macOS(.v13)],
  products: [.executable(name: "LocalShot", targets: ["LocalShot"])],
  targets: [
    .target(name: "LocalShotCore"),
    .executableTarget(name: "LocalShot", dependencies: ["LocalShotCore"]),
    .testTarget(name: "LocalShotCoreTests", dependencies: ["LocalShotCore"]),
  ]
)
