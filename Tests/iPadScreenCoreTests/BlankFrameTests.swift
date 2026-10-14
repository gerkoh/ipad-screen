@testable import iPadScreenCore
import XCTest

final class BlankFrameTests: XCTestCase {
    private let count = BlankFrame.sampleWidth * BlankFrame.sampleHeight

    func testPureBlackIsBlank() {
        XCTAssertTrue(BlankFrame.isBlank(luminance: frame(base: 0)))
    }

    func testNoisyVideoBlackIsBlank() {
        XCTAssertTrue(BlankFrame.isBlank(luminance: frame(base: 16)))
        XCTAssertTrue(BlankFrame.isBlank(luminance: frame(base: BlankFrame.darkLimit)))
    }

    func testAFewHotPixelsStillCountAsBlank() {
        let allowed = Int(Double(count) * BlankFrame.brightAllowance)
        XCTAssertTrue(BlankFrame.isBlank(luminance: frame(base: 0, bright: allowed)))
    }

    func testWhitePageIsNotBlank() {
        XCTAssertFalse(BlankFrame.isBlank(luminance: frame(base: 245)))
    }

    func testDarkModePageWithOneStrokeIsNotBlank() {
        // A short pen line on a black template lifts ~0.5% of samples.
        XCTAssertFalse(BlankFrame.isBlank(luminance: frame(base: 10, bright: count / 200)))
    }

    func testDimGreyIsNotBlank() {
        XCTAssertFalse(BlankFrame.isBlank(luminance: frame(base: BlankFrame.darkLimit + 1)))
    }

    func testNoSamplesIsNotJudgedBlank() {
        XCTAssertFalse(BlankFrame.isBlank(luminance: []))
    }

    // ── Real images, through the downsampling ──

    func testBlackCaptureIsBlank() throws {
        XCTAssertTrue(try BlankFrame.isBlank(image(background: 0)))
    }

    func testWhitePageCaptureIsNotBlank() throws {
        XCTAssertFalse(try BlankFrame.isBlank(image(background: 1)))
    }

    func testThinStrokeOnBlackSurvivesDownsampling() throws {
        // A 3 px pen line across a 1568×1176 black page, as in a dark GoodNotes template.
        let page = try image(background: 0) { context in
            context.setStrokeColor(gray: 1, alpha: 1)
            context.setLineWidth(3)
            context.move(to: CGPoint(x: 400, y: 600))
            context.addLine(to: CGPoint(x: 900, y: 620))
            context.strokePath()
        }
        XCTAssertFalse(BlankFrame.isBlank(page))
    }

    private func image(
        background: CGFloat,
        draw: (CGContext) -> Void = { _ in }
    ) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 1568,
            height: 1176,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(gray: background, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1568, height: 1176))
        draw(context)
        return try XCTUnwrap(context.makeImage())
    }

    private func frame(base: UInt8, bright: Int = 0) -> [UInt8] {
        var samples = [UInt8](repeating: base, count: count)
        for index in stride(from: 0, to: count, by: max(1, count / max(bright, 1))).prefix(bright) {
            samples[index] = 255
        }
        return samples
    }
}
