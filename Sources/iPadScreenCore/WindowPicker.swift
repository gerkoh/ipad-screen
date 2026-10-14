public struct WindowCandidate: Equatable, Sendable {
    public let id: UInt32
    public let bundleID: String?
    public let width: Double
    public let height: Double
    /// 0 is the normal window level; menus, HUDs and the menu-bar strip sit elsewhere.
    public let layer: Int
    public let isOnScreen: Bool

    public init(id: UInt32, bundleID: String?, width: Double, height: Double,
                layer: Int, isOnScreen: Bool) {
        self.id = id
        self.bundleID = bundleID
        self.width = width
        self.height = height
        self.layer = layer
        self.isOnScreen = isOnScreen
    }
}

// Pure: which window is the iPad mirror? Titles aren't used — they're hidden without
// Screen Recording access and localised with it.
public enum WindowPicker {
    public static let quickTimeBundleID = "com.apple.QuickTimePlayerX"
    /// Smaller than any useful mirror; rules out QuickTime's own HUD and strips.
    static let minimumSide = 200.0

    public static func pick(from windows: [WindowCandidate]) -> WindowCandidate? {
        windows
            .filter {
                $0.bundleID == quickTimeBundleID
                    && $0.layer == 0
                    && min($0.width, $0.height) >= minimumSide
            }
            .max { rank($0) < rank($1) }
    }

    // On-screen beats off-screen (minimised or on another Space), then the larger wins.
    private static func rank(_ window: WindowCandidate) -> (Int, Double) {
        (window.isOnScreen ? 1 : 0, window.width * window.height)
    }
}
