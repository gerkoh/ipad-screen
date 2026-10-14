@testable import iPadScreenCore
import XCTest

final class WindowPickerTests: XCTestCase {
    private let quickTime = WindowPicker.quickTimeBundleID

    func testPicksTheQuickTimeMirror() {
        let mirror = window(1, width: 1400, height: 1050)
        let other = window(2, bundleID: "com.anthropic.claudefordesktop", width: 1600, height: 1000)
        XCTAssertEqual(WindowPicker.pick(from: [other, mirror]), mirror)
    }

    func testNoQuickTimeWindowPicksNothing() {
        XCTAssertNil(WindowPicker.pick(from: [window(1, bundleID: "com.apple.Safari")]))
        XCTAssertNil(WindowPicker.pick(from: []))
    }

    func testMissingOwnerIsNotQuickTime() {
        XCTAssertNil(WindowPicker.pick(from: [window(1, bundleID: nil)]))
    }

    func testIgnoresTheMenuBarStripAndHUD() {
        let strip = window(1, width: 1920, height: 30)
        let hud = window(2, width: 290, height: 60)
        XCTAssertNil(WindowPicker.pick(from: [strip, hud]))
    }

    func testAcceptsAWindowExactlyAtTheMinimumSide() {
        let small = window(1, width: 200, height: 200)
        XCTAssertEqual(WindowPicker.pick(from: [small]), small)
    }

    func testIgnoresWindowsOffTheNormalLevel() {
        XCTAssertNil(WindowPicker.pick(from: [window(1, width: 800, height: 600, layer: 25)]))
    }

    func testOnScreenBeatsALargerOffScreenWindow() {
        let visible = window(1, width: 600, height: 800)
        let minimised = window(2, width: 1400, height: 1050, onScreen: false)
        XCTAssertEqual(WindowPicker.pick(from: [minimised, visible]), visible)
    }

    func testFallsBackToAnOffScreenWindow() {
        let minimised = window(2, width: 1400, height: 1050, onScreen: false)
        XCTAssertEqual(WindowPicker.pick(from: [minimised]), minimised)
    }

    func testLargerWinsAmongOnScreenWindows() {
        let small = window(1, width: 640, height: 480)
        let large = window(2, width: 1400, height: 1050)
        XCTAssertEqual(WindowPicker.pick(from: [small, large]), large)
        XCTAssertEqual(WindowPicker.pick(from: [large, small]), large)
    }

    private func window(
        _ id: UInt32,
        bundleID: String? = WindowPicker.quickTimeBundleID,
        width: Double = 1000,
        height: Double = 800,
        layer: Int = 0,
        onScreen: Bool = true
    ) -> WindowCandidate {
        WindowCandidate(id: id, bundleID: bundleID, width: width, height: height,
                        layer: layer, isOnScreen: onScreen)
    }
}
