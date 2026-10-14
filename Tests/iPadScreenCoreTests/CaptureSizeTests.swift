@testable import iPadScreenCore
import XCTest

final class CaptureSizeTests: XCTestCase {
    func testRetinaWindowShrinksToTheLongEdgeLimit() {
        let size = CaptureSize.pixels(width: 1400, height: 1050, scale: 2)
        XCTAssertEqual(size, PixelSize(width: 1568, height: 1176))
    }

    func testPortraitShrinksOnItsHeight() {
        let size = CaptureSize.pixels(width: 1050, height: 1400, scale: 2)
        XCTAssertEqual(size, PixelSize(width: 1176, height: 1568))
    }

    func testSmallWindowIsNotUpscaled() {
        XCTAssertEqual(
            CaptureSize.pixels(width: 600, height: 400, scale: 2),
            PixelSize(width: 1200, height: 800)
        )
    }

    func testExactlyAtTheLimitIsUnchanged() {
        XCTAssertEqual(
            CaptureSize.pixels(width: 784, height: 500, scale: 2),
            PixelSize(width: 1568, height: 1000)
        )
    }

    func testScaleBelowOneIsTreatedAsOne() {
        XCTAssertEqual(
            CaptureSize.pixels(width: 800, height: 600, scale: 0),
            PixelSize(width: 800, height: 600)
        )
    }

    func testDegenerateSizesStayAtLeastOnePixel() {
        XCTAssertEqual(
            CaptureSize.pixels(width: 0, height: -5, scale: 2),
            PixelSize(width: 1, height: 1)
        )
    }

    func testExtremeAspectKeepsTheShortEdgePositive() {
        let size = CaptureSize.pixels(width: 100_000, height: 1, scale: 1)
        XCTAssertEqual(size.width, CaptureSize.maxLongEdge)
        XCTAssertEqual(size.height, 1)
    }
}
