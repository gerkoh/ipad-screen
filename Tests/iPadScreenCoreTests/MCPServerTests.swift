import Foundation
@testable import iPadScreenCore
import XCTest

final class MCPServerTests: XCTestCase {
    private let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02])
    private let version = "9.8.7"

    // ── Lifecycle ──

    func testInitializeEchoesASupportedProtocolVersion() throws {
        let reply = try send(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{}}}"#)
        XCTAssertEqual(reply["id"], .number(1))
        XCTAssertEqual(reply["result"]?["protocolVersion"], .string("2025-03-26"))
        XCTAssertEqual(reply["result"]?["capabilities"]?["tools"], .object([:]))
        XCTAssertEqual(reply["result"]?["serverInfo"]?["name"], .string(MCPServer.serverName))
        XCTAssertEqual(reply["result"]?["serverInfo"]?["version"], .string(version))
        XCTAssertNotNil(reply["result"]?["instructions"]?.stringValue)
    }

    func testInitializeOffersTheNewestVersionForAnUnknownOne() throws {
        let reply = try send(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2099-01-01"}}"#)
        XCTAssertEqual(
            reply["result"]?["protocolVersion"],
            .string(MCPServer.supportedProtocolVersions[0])
        )
    }

    func testInitializeWithoutParamsStillAnswers() throws {
        let reply = try send(#"{"jsonrpc":"2.0","id":1,"method":"initialize"}"#)
        XCTAssertEqual(
            reply["result"]?["protocolVersion"],
            .string(MCPServer.supportedProtocolVersions[0])
        )
    }

    func testNotificationsGetNoReply() {
        let server = MCPServer(version: version) { XCTFail("no capture expected"); return .unavailable("") }
        XCTAssertNil(server.handle(line: #"{"jsonrpc":"2.0","method":"notifications/initialized"}"#))
        XCTAssertNil(server.handle(line: #"{"jsonrpc":"2.0","method":"tools/call","params":{"name":"view_ipad_screen"}}"#))
    }

    func testPingAnswersEmpty() throws {
        let reply = try send(#"{"jsonrpc":"2.0","id":"p","method":"ping"}"#)
        XCTAssertEqual(reply["id"], .string("p"))
        XCTAssertEqual(reply["result"], .object([:]))
    }

    // ── Tools ──

    func testToolsListAdvertisesTheReadOnlyScreenTool() throws {
        let reply = try send(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
        guard case let .array(tools)? = reply["result"]?["tools"] else {
            return XCTFail("tools missing")
        }
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools[0]["name"], .string(MCPServer.toolName))
        XCTAssertEqual(tools[0]["inputSchema"]?["type"], .string("object"))
        XCTAssertEqual(tools[0]["annotations"]?["readOnlyHint"], .bool(true))
    }

    func testToolCallReturnsTheCaptureAsAJPEGImage() throws {
        let reply = try send(
            #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"view_ipad_screen","arguments":{}}}"#,
            capture: .image(jpeg: jpeg)
        )
        XCTAssertEqual(reply["result"]?["isError"], .bool(false))
        let item = try XCTUnwrap(firstContent(reply))
        XCTAssertEqual(item["type"], .string("image"))
        XCTAssertEqual(item["mimeType"], .string("image/jpeg"))
        XCTAssertEqual(item["data"]?.stringValue.flatMap { Data(base64Encoded: $0) }, jpeg)
    }

    func testToolCallSurfacesAnUnavailableCaptureAsAToolError() throws {
        let reply = try send(
            #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"view_ipad_screen"}}"#,
            capture: .unavailable("QuickTime isn't open")
        )
        XCTAssertNil(reply["error"], "a capture problem is a tool result, not a protocol error")
        XCTAssertEqual(reply["result"]?["isError"], .bool(true))
        let item = try XCTUnwrap(firstContent(reply))
        XCTAssertEqual(item["type"], .string("text"))
        XCTAssertEqual(item["text"], .string("QuickTime isn't open"))
    }

    func testToolCallCapturesFreshEachTime() throws {
        var captures = 0
        let server = MCPServer(version: version) { captures += 1; return .image(jpeg: self.jpeg) }
        let call = #"{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"view_ipad_screen"}}"#
        _ = server.handle(line: call)
        _ = server.handle(line: call)
        XCTAssertEqual(captures, 2)
    }

    func testUnknownToolIsAnInvalidParamsErrorWithoutCapturing() throws {
        var captured = false
        let server = MCPServer(version: version) { captured = true; return .image(jpeg: self.jpeg) }
        let reply = try decode(XCTUnwrap(server.handle(
            line: #"{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"rm_rf"}}"#
        )))
        XCTAssertEqual(reply["error"]?["code"], .number(Double(MCPServer.ErrorCode.invalidParams)))
        XCTAssertFalse(captured)
    }

    func testToolCallWithoutParamsIsAnInvalidParamsError() throws {
        let reply = try send(#"{"jsonrpc":"2.0","id":7,"method":"tools/call"}"#)
        XCTAssertEqual(reply["error"]?["code"], .number(Double(MCPServer.ErrorCode.invalidParams)))
    }

    // ── Malformed input ──

    func testUnknownMethodIsMethodNotFound() throws {
        let reply = try send(#"{"jsonrpc":"2.0","id":8,"method":"resources/list"}"#)
        XCTAssertEqual(reply["id"], .number(8))
        XCTAssertEqual(reply["error"]?["code"], .number(Double(MCPServer.ErrorCode.methodNotFound)))
    }

    func testUnparseableLineIsAParseErrorWithNullID() throws {
        let reply = try send("{not json")
        XCTAssertEqual(reply["id"], .null)
        XCTAssertEqual(reply["error"]?["code"], .number(Double(MCPServer.ErrorCode.parse)))
    }

    func testNonObjectMessageIsAnInvalidRequest() throws {
        let reply = try send(#"[{"jsonrpc":"2.0","id":1,"method":"ping"}]"#)
        XCTAssertEqual(reply["error"]?["code"], .number(Double(MCPServer.ErrorCode.invalidRequest)))
    }

    func testRequestWithoutAMethodIsAnInvalidRequest() throws {
        let reply = try send(#"{"jsonrpc":"2.0","id":9}"#)
        XCTAssertEqual(reply["id"], .number(9))
        XCTAssertEqual(reply["error"]?["code"], .number(Double(MCPServer.ErrorCode.invalidRequest)))
    }

    // ── Wire format ──

    func testRepliesAreSingleLineAndKeepIntegerIDsIntegral() throws {
        let server = MCPServer(version: version) { .image(jpeg: Data(repeating: 0xAB, count: 4096)) }
        let line = try XCTUnwrap(server.handle(
            line: #"{"jsonrpc":"2.0","id":42,"method":"tools/call","params":{"name":"view_ipad_screen"}}"#
        ))
        XCTAssertFalse(line.contains("\n"), "stdio messages must not contain newlines")
        XCTAssertTrue(line.contains(#""id":42"#), line.prefix(200).description)
        XCTAssertTrue(line.contains(#""jsonrpc":"2.0""#))
    }

    // ── Helpers ──

    private func send(_ line: String, capture: CaptureOutcome = .unavailable("unused")) throws -> JSONValue {
        let server = MCPServer(version: version) { capture }
        return try decode(XCTUnwrap(server.handle(line: line)))
    }

    private func decode(_ line: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(line.utf8))
    }

    private func firstContent(_ reply: JSONValue) -> JSONValue? {
        guard case let .array(items)? = reply["result"]?["content"] else { return nil }
        return items.first
    }
}
