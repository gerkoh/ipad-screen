import Foundation

/// The contract between the MCP server and the capture app: the server names an output
/// path; the app writes a JPEG there on success, or a message beside it on failure.
public enum CaptureHandoff {
    public static let outputFlag = "--out"
    public static let appName = "iPadScreenCapture.app"

    public static func outputPath(in arguments: [String]) -> String? {
        guard let flag = arguments.firstIndex(of: outputFlag),
              arguments.indices.contains(flag + 1) else { return nil }
        let path = arguments[flag + 1]
        return path.isEmpty ? nil : path
    }

    public static func errorURL(for output: URL) -> URL {
        output.appendingPathExtension("error")
    }

    /// Reads what the capture app left behind, then removes both files so no screenshot
    /// outlives the request.
    public static func collect(output: URL, fileManager: FileManager = .default) -> CaptureOutcome {
        let errorFile = errorURL(for: output)
        defer {
            try? fileManager.removeItem(at: output)
            try? fileManager.removeItem(at: errorFile)
        }
        if let data = fileManager.contents(atPath: output.path), !data.isEmpty {
            return .image(jpeg: data)
        }
        if let data = fileManager.contents(atPath: errorFile.path), !data.isEmpty {
            return .unavailable(String(decoding: data, as: UTF8.self))
        }
        return .unavailable(CaptureMessage.noResult)
    }
}

public enum CaptureMessage {
    public static let noQuickTimeWindow = """
    No QuickTime Player window is showing the iPad. Ask the user to open QuickTime \
    Player, choose File › New Movie Recording, and pick their iPad as the camera \
    (the ⌄ next to the record button).
    """
    public static let permissionNeeded = """
    iPadScreenCapture doesn't have Screen Recording permission yet. Ask the user to turn \
    it on in System Settings › Privacy & Security › Screen & System Audio Recording, \
    then try again.
    """
    public static let timedOut = "Capturing the iPad screen timed out. Ask the user to try again."
    public static let noResult = "The capture app finished without producing an image."
    public static let appMissing = """
    iPadScreenCapture.app wasn't found next to the MCP server. Rebuild with `just build`.
    """

    public static func captureFailed(_ detail: String) -> String {
        "Couldn't capture the iPad screen: \(detail)"
    }
}
