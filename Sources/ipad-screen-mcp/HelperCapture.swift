import Foundation
import iPadScreenCore

/// Runs iPadScreenCapture.app once per request. It's launched through `open` so macOS
/// treats it as its own app: the Screen Recording grant is its alone, never inherited
/// by Claude or anything else Claude starts.
struct HelperCapture {
    static let timeout: TimeInterval = 20

    let appURL: URL?

    static func locateApp() -> URL? {
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            return nil
        }
        let app = executable.deletingLastPathComponent()
            .appendingPathComponent(CaptureHandoff.appName)
        return FileManager.default.fileExists(atPath: app.path) ? app : nil
    }

    func capture() -> CaptureOutcome {
        guard let appURL else { return .unavailable(CaptureMessage.appMissing) }
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("ipad-screen-\(UUID().uuidString).jpg")

        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        // -n: a fresh instance per request; -g: never take focus from Claude;
        // -W: return only once the capture app has exited.
        open.arguments = [
            "-n", "-g", "-W", appURL.path,
            "--args", CaptureHandoff.outputFlag, output.path,
        ]
        open.standardOutput = FileHandle.nullDevice
        open.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        open.terminationHandler = { _ in finished.signal() }

        do {
            try open.run()
        } catch {
            return .unavailable(CaptureMessage.captureFailed(error.localizedDescription))
        }
        guard finished.wait(timeout: .now() + Self.timeout) == .success else {
            open.terminate()
            _ = CaptureHandoff.collect(output: output)
            return .unavailable(CaptureMessage.timedOut)
        }
        return CaptureHandoff.collect(output: output)
    }
}
