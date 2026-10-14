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
    static let timeout: TimeInterval = 10
    static let jpegQuality = 0.85

    /// Blocks the calling (stdin) thread until the capture finishes or times out.
    static func captureNow() -> CaptureOutcome {
        let result = OutcomeBox()
        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            result.set(await outcome())
            finished.signal()
        }
        guard finished.wait(timeout: .now() + timeout) == .success, let outcome = result.get()
        else { return .unavailable(CaptureMessage.timedOut) }
        return outcome
    }

    private static func outcome() async -> CaptureOutcome {
        do {
            return try await .image(jpeg: jpeg())
        } catch let failure as CaptureFailure {
            return .unavailable(failure.message)
        } catch {
            return .unavailable(CaptureMessage.captureFailed(error.localizedDescription))
        }
    }

    private static func jpeg() async throws -> Data {
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
        // windows (Claude, say) cover it, and nothing else on screen.
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

/// @unchecked Sendable: every access goes through `lock`.
private final class OutcomeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var outcome: CaptureOutcome?

    func set(_ value: CaptureOutcome) {
        lock.withLock { outcome = value }
    }

    func get() -> CaptureOutcome? {
        lock.withLock { outcome }
    }
}
