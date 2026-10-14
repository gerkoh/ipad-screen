/// Problems the user can act on, worded for Claude to relay.
public enum CaptureMessage {
    public static let noQuickTimeWindow = """
    No QuickTime Player window is showing the iPad. Ask the user to open QuickTime \
    Player, choose File › New Movie Recording, and pick their iPad as the camera \
    (the ⌄ next to the record button). The window can be covered but not minimised.
    """
    public static let permissionNeeded = """
    iPadScreen doesn't have Screen Recording permission yet. Ask the user to turn it on \
    in System Settings › Privacy & Security › Screen & System Audio Recording, then \
    restart Claude Desktop.
    """
    public static let timedOut = "Capturing the iPad screen timed out. Ask the user to try again."

    public static func captureFailed(_ detail: String) -> String {
        "Couldn't capture the iPad screen: \(detail)"
    }
}
