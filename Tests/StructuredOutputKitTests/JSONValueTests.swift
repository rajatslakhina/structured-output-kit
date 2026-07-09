import XCTest
@testable import StructuredOutputKit

final class JSONValueTests: XCTestCase {
    private func decode(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    func testDecodesNull() throws {
        XCTAssertEqual(try decode("null"), .null)
    }

    func testDecodesBoolTrueAndFalse() throws {
        XCTAssertEqual(try decode("true"), .bool(true))
        XCTAssertEqual(try decode("false"), .bool(false))
    }

    func testDecodesNumberDistinctFromBool() throws {
        XCTAssertEqual(try decode("42"), .number(42))
        XCTAssertEqual(try decode("3.5"), .number(3.5))
        XCTAssertNotEqual(try decode("1"), .bool(true))
        XCTAssertNotEqual(try decode("0"), .bool(false))
    }

    func testDecodesString() throws {
        XCTAssertEqual(try decode(#""hello""#), .string("hello"))
    }

    func testDecodesArray() throws {
        XCTAssertEqual(try decode("[1, \"two\", true, null]"), .array([.number(1), .string("two"), .bool(true), .null]))
    }

    func testDecodesObject() throws {
        let value = try decode(#"{"a": 1, "b": "two"}"#)
        XCTAssertEqual(value, .object(["a": .number(1), "b": .string("two")]))
    }

    func testDecodesDeeplyNestedStructure() throws {
        let value = try decode(#"{"items": [{"n": 1}, {"n": 2}], "ok": true}"#)
        XCTAssertEqual(
            value,
            .object([
                "items": .array([.object(["n": .number(1)]), .object(["n": .number(2)])]),
                "ok": .bool(true)
            ])
        )
    }

    func testEncodeDecodeRoundTrip() throws {
        let original = JSONValue.object([
            "list": .array([.number(1), .bool(false), .null, .string("x")])
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEncodesEachCaseWithoutThrowing() throws {
        let encoder = JSONEncoder()
        for value: JSONValue in [
            .object(["k": .string("v")]),
            .array([.number(1)]),
            .string("s"),
            .number(1.5),
            .bool(true),
            .null
        ] {
            XCTAssertNoThrow(try encoder.encode(value))
        }
    }
}
