import Foundation
@testable import iPadScreenCore
import XCTest

final class CaptureHandoffTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ipad-screen-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    // ── Arguments ──

    func testReadsTheOutputPathAfterTheFlag() {
        XCTAssertEqual(
            CaptureHandoff.outputPath(in: ["/app", "--out", "/tmp/x.jpg"]),
            "/tmp/x.jpg"
        )
    }

    func testIgnoresLaunchServicesNoiseAroundTheFlag() {
        XCTAssertEqual(
            CaptureHandoff.outputPath(in: ["/app", "-psn_0_12345", "--out", "/tmp/x.jpg", "extra"]),
            "/tmp/x.jpg"
        )
    }

    func testMissingOrEmptyPathIsNil() {
        XCTAssertNil(CaptureHandoff.outputPath(in: ["/app"]))
        XCTAssertNil(CaptureHandoff.outputPath(in: ["/app", "--out"]))
        XCTAssertNil(CaptureHandoff.outputPath(in: ["/app", "--out", ""]))
    }

    // ── Collecting the result ──

    func testImageIsReturnedAndRemoved() throws {
        let output = directory.appendingPathComponent("shot.jpg")
        let jpeg = Data([0xFF, 0xD8, 0xFF])
        try jpeg.write(to: output)
        XCTAssertEqual(CaptureHandoff.collect(output: output), .image(jpeg: jpeg))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    func testErrorMessageIsReturnedAndRemoved() throws {
        let output = directory.appendingPathComponent("shot.jpg")
        let errorFile = CaptureHandoff.errorURL(for: output)
        try Data("permission needed".utf8).write(to: errorFile)
        XCTAssertEqual(CaptureHandoff.collect(output: output), .unavailable("permission needed"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: errorFile.path))
    }

    func testImageWinsWhenBothExistAndBothAreRemoved() throws {
        let output = directory.appendingPathComponent("shot.jpg")
        let errorFile = CaptureHandoff.errorURL(for: output)
        try Data([0xFF, 0xD8]).write(to: output)
        try Data("late watchdog".utf8).write(to: errorFile)
        XCTAssertEqual(CaptureHandoff.collect(output: output), .image(jpeg: Data([0xFF, 0xD8])))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: errorFile.path))
    }

    func testEmptyImageFileFallsThroughToTheError() throws {
        let output = directory.appendingPathComponent("shot.jpg")
        try Data().write(to: output)
        try Data("encoder failed".utf8).write(to: CaptureHandoff.errorURL(for: output))
        XCTAssertEqual(CaptureHandoff.collect(output: output), .unavailable("encoder failed"))
    }

    func testNothingWrittenIsReportedNotSilent() {
        let output = directory.appendingPathComponent("shot.jpg")
        XCTAssertEqual(
            CaptureHandoff.collect(output: output),
            .unavailable(CaptureMessage.noResult)
        )
    }

    func testErrorFileSitsBesideTheOutput() {
        let output = URL(fileURLWithPath: "/tmp/a/shot.jpg")
        XCTAssertEqual(CaptureHandoff.errorURL(for: output).path, "/tmp/a/shot.jpg.error")
    }
}
