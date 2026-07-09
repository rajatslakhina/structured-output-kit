import XCTest
@testable import StructuredOutputKit

final class SchemaValidatorTests: XCTestCase {
    // MARK: - Object

    func testObjectMatchesWhenAllRequiredPropertiesPresentAndValid() {
        let schema = JSONSchema.object(properties: ["name": .string()], required: ["name"])
        let value = JSONValue.object(["name": .string("Ada")])
        XCTAssertNil(SchemaValidator.firstMismatch(of: value, against: schema))
    }

    func testObjectAllowsExtraUnspecifiedProperties() {
        let schema = JSONSchema.object(properties: ["name": .string()], required: ["name"])
        let value = JSONValue.object(["name": .string("Ada"), "extra": .bool(true)])
        XCTAssertNil(SchemaValidator.firstMismatch(of: value, against: schema))
    }

    func testObjectWithNoPropertiesSchemaOnlyChecksRequired() {
        let schema = JSONSchema(kind: .object, required: ["id"])
        XCTAssertNil(SchemaValidator.firstMismatch(of: .object(["id": .number(1)]), against: schema))
    }

    func testObjectMismatchWhenValueIsNotAnObject() {
        let schema = JSONSchema.object(properties: [:])
        let mismatch = SchemaValidator.firstMismatch(of: .string("nope"), against: schema)
        XCTAssertEqual(mismatch, "$ expected object, got string")
    }

    func testObjectMismatchWhenRequiredKeyMissing() {
        let schema = JSONSchema.object(properties: ["name": .string()], required: ["name"])
        let mismatch = SchemaValidator.firstMismatch(of: .object([:]), against: schema)
        XCTAssertEqual(mismatch, "$.name is required but missing")
    }

    func testObjectMismatchPropagatesFromNestedProperty() {
        let schema = JSONSchema.object(properties: ["age": .integer()], required: ["age"])
        let value = JSONValue.object(["age": .string("old")])
        let mismatch = SchemaValidator.firstMismatch(of: value, against: schema)
        XCTAssertEqual(mismatch, "$.age expected integer, got string")
    }

    func testObjectSkipsValidationForOptionalPropertyAbsentFromValue() {
        let schema = JSONSchema.object(
            properties: ["name": .string(), "nickname": .string()],
            required: ["name"]
        )
        // "nickname" is a declared property but is simply missing from the
        // value; since it isn't required, that's fine and should not be
        // treated as a mismatch.
        let value = JSONValue.object(["name": .string("Ada")])
        XCTAssertNil(SchemaValidator.firstMismatch(of: value, against: schema))
    }

    // MARK: - Array

    func testArrayMatchesWhenAllItemsValid() {
        let schema = JSONSchema.array(of: .integer())
        XCTAssertNil(SchemaValidator.firstMismatch(of: .array([.number(1), .number(2)]), against: schema))
    }

    func testArrayWithNoItemSchemaAcceptsAnything() {
        let schema = JSONSchema(kind: .array)
        XCTAssertNil(SchemaValidator.firstMismatch(of: .array([.string("x"), .bool(true)]), against: schema))
    }

    func testArrayMismatchWhenValueIsNotAnArray() {
        let schema = JSONSchema.array(of: .string())
        let mismatch = SchemaValidator.firstMismatch(of: .object([:]), against: schema)
        XCTAssertEqual(mismatch, "$ expected array, got object")
    }

    func testArrayMismatchPropagatesFromElementWithIndex() {
        let schema = JSONSchema.array(of: .string())
        let value = JSONValue.array([.string("ok"), .number(1)])
        let mismatch = SchemaValidator.firstMismatch(of: value, against: schema)
        XCTAssertEqual(mismatch, "$[1] expected string, got number")
    }

    // MARK: - String / enum

    func testStringMatchesWithoutEnum() {
        XCTAssertNil(SchemaValidator.firstMismatch(of: .string("anything"), against: .string()))
    }

    func testStringMismatchWhenNotAString() {
        let mismatch = SchemaValidator.firstMismatch(of: .number(1), against: .string())
        XCTAssertEqual(mismatch, "$ expected string, got number")
    }

    func testStringEnumMatches() {
        let schema = JSONSchema.string(enumValues: ["red", "green"])
        XCTAssertNil(SchemaValidator.firstMismatch(of: .string("red"), against: schema))
    }

    func testStringEnumMismatch() {
        let schema = JSONSchema.string(enumValues: ["red", "green"])
        let mismatch = SchemaValidator.firstMismatch(of: .string("blue"), against: schema)
        XCTAssertEqual(mismatch, "$ expected one of [\"red\", \"green\"], got blue")
    }

    // MARK: - Number / integer / boolean / null

    func testNumberMatches() {
        XCTAssertNil(SchemaValidator.firstMismatch(of: .number(3.14), against: .number()))
    }

    func testNumberMismatch() {
        let mismatch = SchemaValidator.firstMismatch(of: .bool(true), against: .number())
        XCTAssertEqual(mismatch, "$ expected number, got boolean")
    }

    func testIntegerMatchesWholeNumber() {
        XCTAssertNil(SchemaValidator.firstMismatch(of: .number(4), against: .integer()))
    }

    func testIntegerMismatchForFractionalNumber() {
        let mismatch = SchemaValidator.firstMismatch(of: .number(4.5), against: .integer())
        XCTAssertEqual(mismatch, "$ expected an integer")
    }

    func testIntegerMismatchWhenNotANumberAtAll() {
        let mismatch = SchemaValidator.firstMismatch(of: .string("4"), against: .integer())
        XCTAssertEqual(mismatch, "$ expected integer, got string")
    }

    func testBooleanMatches() {
        XCTAssertNil(SchemaValidator.firstMismatch(of: .bool(false), against: .boolean()))
    }

    func testBooleanMismatch() {
        let mismatch = SchemaValidator.firstMismatch(of: .number(0), against: .boolean())
        XCTAssertEqual(mismatch, "$ expected boolean, got number")
    }

    func testNullMatches() {
        let schema = JSONSchema(kind: .null)
        XCTAssertNil(SchemaValidator.firstMismatch(of: .null, against: schema))
    }

    func testNullMismatch() {
        let schema = JSONSchema(kind: .null)
        let mismatch = SchemaValidator.firstMismatch(of: .bool(true), against: schema)
        XCTAssertEqual(mismatch, "$ expected null, got boolean")
    }

    // MARK: - Mismatch message kind naming

    func testMismatchMessageNamesArrayKind() {
        let mismatch = SchemaValidator.firstMismatch(of: .array([]), against: .string())
        XCTAssertEqual(mismatch, "$ expected string, got array")
    }

    func testMismatchMessageNamesNullKind() {
        let mismatch = SchemaValidator.firstMismatch(of: .null, against: .string())
        XCTAssertEqual(mismatch, "$ expected string, got null")
    }
}
