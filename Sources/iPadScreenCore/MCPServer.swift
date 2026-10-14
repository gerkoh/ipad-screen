import Foundation

public enum CaptureOutcome: Equatable, Sendable {
    case image(jpeg: Data)
    /// Something the user can act on (QuickTime closed, permission missing, …), worded
    /// for Claude to relay.
    case unavailable(String)
}

/// The Model Context Protocol over stdio: newline-delimited JSON-RPC 2.0.
/// https://modelcontextprotocol.io/specification/2025-06-18/basic/transports#stdio
public struct MCPServer {
    public static let serverName = "ipad-screen"
    public static let serverVersion = "1.0.0"
    public static let toolName = "view_ipad_screen"
    /// Newest first; the first is offered when a client asks for one we don't know.
    static let supportedProtocolVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]

    enum ErrorCode {
        static let parse = -32700
        static let invalidRequest = -32600
        static let methodNotFound = -32601
        static let invalidParams = -32602
    }

    private let capture: () -> CaptureOutcome

    public init(capture: @escaping () -> CaptureOutcome) {
        self.capture = capture
    }

    /// One line from stdin in; the line to write to stdout, or nil when the message is a
    /// notification (which never gets a reply).
    public func handle(line: String) -> String? {
        let message: JSONValue
        do {
            message = try JSONDecoder().decode(JSONValue.self, from: Data(line.utf8))
        } catch {
            return Self.encode(Self.error(id: .null, code: ErrorCode.parse, message: "Parse error"))
        }
        return handle(message).map(Self.encode)
    }

    func handle(_ message: JSONValue) -> JSONValue? {
        guard case let .object(fields) = message else {
            return Self.error(id: .null, code: ErrorCode.invalidRequest, message: "Invalid request")
        }
        guard let id = fields["id"] else { return nil }
        guard let method = fields["method"]?.stringValue else {
            return Self.error(id: id, code: ErrorCode.invalidRequest, message: "Invalid request")
        }
        let params = fields["params"]
        switch method {
        case "initialize":
            return Self.result(id: id, initializeResult(requested: params?["protocolVersion"]))
        case "ping":
            return Self.result(id: id, .object([:]))
        case "tools/list":
            return Self.result(id: id, .object(["tools": .array([Self.tool])]))
        case "tools/call":
            guard params?["name"]?.stringValue == Self.toolName else {
                return Self.error(id: id, code: ErrorCode.invalidParams, message: "Unknown tool")
            }
            return Self.result(id: id, Self.toolResult(capture()))
        default:
            return Self.error(id: id, code: ErrorCode.methodNotFound, message: "Method not found")
        }
    }

    private func initializeResult(requested: JSONValue?) -> JSONValue {
        let version = requested?.stringValue
            .flatMap { Self.supportedProtocolVersions.contains($0) ? $0 : nil }
            ?? Self.supportedProtocolVersions[0]
        return .object([
            "protocolVersion": .string(version),
            "capabilities": .object(["tools": .object([:])]),
            "serverInfo": .object([
                "name": .string(Self.serverName),
                "version": .string(Self.serverVersion),
            ]),
            "instructions": .string(Self.instructions),
        ])
    }

    static let instructions = """
    The user works on an iPad (usually handwritten notes and maths in GoodNotes) that is \
    mirrored to this Mac in a QuickTime Player window. Call \(toolName) to see their iPad \
    screen whenever they refer to what they are writing, reading or doing on it, before \
    answering. Take a fresh look each time; the page changes as they write.
    """

    static let tool: JSONValue = .object([
        "name": .string(toolName),
        "title": .string("View iPad screen"),
        "description": .string("""
        Returns a current screenshot of the user's iPad screen, mirrored to this Mac \
        through QuickTime Player. Use it whenever the user asks about what is on their \
        iPad — e.g. "check my working", "what's wrong with this step", "help with this \
        question" — and again after they say they've written more.
        """),
        "inputSchema": .object([
            "type": .string("object"),
            "properties": .object([:]),
        ]),
        "annotations": .object([
            "readOnlyHint": .bool(true),
            "openWorldHint": .bool(false),
        ]),
    ])

    static func toolResult(_ outcome: CaptureOutcome) -> JSONValue {
        switch outcome {
        case let .image(jpeg):
            .object([
                "content": .array([.object([
                    "type": .string("image"),
                    "data": .string(jpeg.base64EncodedString()),
                    "mimeType": .string("image/jpeg"),
                ])]),
                "isError": .bool(false),
            ])
        case let .unavailable(reason):
            .object([
                "content": .array([.object([
                    "type": .string("text"),
                    "text": .string(reason),
                ])]),
                "isError": .bool(true),
            ])
        }
    }

    private static func result(id: JSONValue, _ result: JSONValue) -> JSONValue {
        .object(["jsonrpc": .string("2.0"), "id": id, "result": result])
    }

    private static func error(id: JSONValue, code: Int, message: String) -> JSONValue {
        .object([
            "jsonrpc": .string("2.0"),
            "id": id,
            "error": .object(["code": .number(Double(code)), "message": .string(message)]),
        ])
    }

    private static func encode(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Encoding a JSONValue can't fail: it holds only JSON-representable values.
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
