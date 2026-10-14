import Foundation
@testable import iPadScreenCore
import XCTest

final class JSONValueTests: XCTestCase {
    func testRoundTripsEveryKind() throws {
        let value: JSONValue = .object([
            "null": .null,
            "bool": .bool(true),
            "int": .number(7),
            "fraction": .number(0.5),
            "string": .string("x/y"),
            "array": .array([.number(1), .string("two")]),
        ])
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(JSONValue.self, from: data), value)
    }

    func testIntegralNumbersEncodeWithoutAFraction() throws {
        let data = try JSONEncoder().encode(JSONValue.number(42))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "42")
    }

    func testBooleansAreNotReadAsNumbers() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data("true".utf8))
        XCTAssertEqual(value, .bool(true))
    }

    func testSubscriptOnlyReadsObjects() {
        XCTAssertNil(JSONValue.string("a")["key"])
        XCTAssertEqual(JSONValue.object(["key": .null])["key"], .null)
        XCTAssertNil(JSONValue.number(1).stringValue)
    }
}
