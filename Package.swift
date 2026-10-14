// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "iPadScreen",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: the MCP protocol, window choice and capture sizing. No I/O, so
        // it's unit-tested without a screen, an iPad or Claude.
        .target(name: "iPadScreenCore"),
        // The stdio MCP server Claude launches. Holds no permissions of its own.
        .executableTarget(
            name: "ipad-screen-mcp",
            dependencies: ["iPadScreenCore"]
        ),
        // Bundled as iPadScreenCapture.app so the Screen Recording grant belongs to it,
        // not to Claude (see README "Why a separate capture app").
        .executableTarget(
            name: "iPadScreenCapture",
            dependencies: ["iPadScreenCore"]
        ),
        .testTarget(
            name: "iPadScreenCoreTests",
            dependencies: ["iPadScreenCore"]
        ),
    ]
)
