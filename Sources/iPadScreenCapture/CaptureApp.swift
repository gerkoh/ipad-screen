import AppKit
import CoreGraphics
import Foundation
import ImageIO
import iPadScreenCore
import ScreenCaptureKit
import UniformTypeIdentifiers

struct CaptureFailure: Error {
    let message: String
}

enum QuickTimeWindowCapture {
    static let jpegQuality = 0.85

    static func jpeg() async throws -> Data {
        guard CGPreflightScreenCaptureAccess() else {
            // Shows the system prompt the first time; the grant applies from the next launch.
            _ = CGRequestScreenCaptureAccess()
            throw CaptureFailure(message: CaptureMessage.permissionNeeded)
        }
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: false
        )
        let candidates = content.windows.map { window in
            WindowCandidate(
                id: window.windowID,
                bundleID: window.owningApplication?.bundleIdentifier,
                width: window.frame.width,
                height: window.frame.height,
                layer: window.windowLayer,
                isOnScreen: window.isOnScreen
            )
        }
        guard let chosen = WindowPicker.pick(from: candidates),
              let window = content.windows.first(where: { $0.windowID == chosen.id })
        else { throw CaptureFailure(message: CaptureMessage.noQuickTimeWindow) }

        // A single-window filter captures the window's own pixels even when other
        // windows (Claude, say) cover it.
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let size = CaptureSize.pixels(
            width: window.frame.width,
            height: window.frame.height,
            scale: Double(filter.pointPixelScale)
        )
        let configuration = SCStreamConfiguration()
        configuration.width = size.width
        configuration.height = size.height
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        return try encodeJPEG(image)
    }

    private static func encodeJPEG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { throw CaptureFailure(message: CaptureMessage.captureFailed("no JPEG encoder")) }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: jpegQuality,
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CaptureFailure(message: CaptureMessage.captureFailed("JPEG encoding failed"))
        }
        return data as Data
    }
}

@main
enum CaptureApp {
    static let watchdog: TimeInterval = 15

    static func main() async {
        guard let path = CaptureHandoff.outputPath(in: CommandLine.arguments) else {
            exit(EX_USAGE)
        }
        let output = URL(fileURLWithPath: path)
        let errorFile = CaptureHandoff.errorURL(for: output)

        // Opens the window-server connection. Launched by `open` as a background-only app,
        // nothing else does, and SCContentFilter then aborts inside SkyLight
        // (SLSGetDisplaysWithRect assertion) instead of throwing.
        await MainActor.run {
            _ = NSApplication.shared.setActivationPolicy(.prohibited)
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + watchdog) {
            try? Data(CaptureMessage.timedOut.utf8).write(to: errorFile)
            exit(EXIT_FAILURE)
        }

        do {
            try await QuickTimeWindowCapture.jpeg().write(to: output, options: .atomic)
            exit(EXIT_SUCCESS)
        } catch {
            let message = (error as? CaptureFailure)?.message
                ?? CaptureMessage.captureFailed(error.localizedDescription)
            try? Data(message.utf8).write(to: errorFile)
            exit(EXIT_FAILURE)
        }
    }
}
