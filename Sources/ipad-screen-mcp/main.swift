import AppKit
import Foundation
import iPadScreenCore

// Opens the window-server connection ScreenCaptureKit needs; without it SCContentFilter
// aborts inside SkyLight (SLSGetDisplaysWithRect assertion) instead of throwing.
_ = NSApplication.shared.setActivationPolicy(.prohibited)

// stdin is read off the main thread so the main queue stays free for the frameworks.
// stdout carries only protocol messages; anything else would corrupt the stream.
Thread.detachNewThread {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
    let server = MCPServer(version: version as? String ?? "dev") {
        QuickTimeWindowCapture.captureNow()
    }
    while let line = readLine(strippingNewline: true) {
        guard !line.allSatisfy(\.isWhitespace) else { continue }
        if let reply = server.handle(line: line) {
            FileHandle.standardOutput.write(Data((reply + "\n").utf8))
        }
    }
    exit(EXIT_SUCCESS)
}

dispatchMain()
