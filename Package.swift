// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "iPadScreen",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic: the MCP protocol, window choice and capture sizing. No I/O, so
        // it's unit-tested without a screen, an iPad or Claude.
        .target(name: "iPadScreenCore"),
        // The stdio MCP server Claude launches; bundled as iPadScreen.app so macOS shows
        // a named app for the Screen Recording grant.
        .executableTarget(
            name: "ipad-screen-mcp",
            dependencies: ["iPadScreenCore"]
        ),
        .testTarget(
            name: "iPadScreenCoreTests",
            dependencies: ["iPadScreenCore"]
        ),
    ]
)
