import XCTest
@testable import StructuredOutputKit

final class JSONSchemaTests: XCTestCase {
    func testObjectConvenienceConstructor() {
        let schema = JSONSchema.object(
            properties: ["name": .string()],
            required: ["name"],
            description: "A person"
        )
        XCTAssertEqual(schema.kind, .object)
        XCTAssertEqual(schema.description, "A person")
        XCTAssertEqual(schema.properties?["name"], .string())
        XCTAssertEqual(schema.required, ["name"])
    }

    func testArrayConvenienceConstructorBoxesItems() {
        let schema = JSONSchema.array(of: .integer(), description: "some ints")
        XCTAssertEqual(schema.kind, .array)
        XCTAssertEqual(schema.description, "some ints")
        XCTAssertEqual(schema.items?.schema, .integer())
    }

    func testStringConvenienceConstructorWithEnum() {
        let schema = JSONSchema.string(description: "a color", enumValues: ["red", "green"])
        XCTAssertEqual(schema.kind, .string)
        XCTAssertEqual(schema.description, "a color")
        XCTAssertEqual(schema.enumValues, ["red", "green"])
    }

    func testNumberIntegerBooleanConvenienceConstructors() {
        XCTAssertEqual(JSONSchema.number(description: "n").kind, .number)
        XCTAssertEqual(JSONSchema.integer(description: "i").kind, .integer)
        XCTAssertEqual(JSONSchema.boolean(description: "b").kind, .boolean)
    }

    func testEquatableIgnoresNothingRelevant() {
        let a = JSONSchema.string(description: "x")
        let b = JSONSchema.string(description: "x")
        let c = JSONSchema.string(description: "y")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testCodableRoundTripThroughNestedStructure() throws {
        let schema = JSONSchema.object(
            properties: [
                "tags": .array(of: .string(enumValues: ["a", "b"])),
                "nested": .object(properties: ["count": .integer()], required: ["count"])
            ],
            required: ["tags"]
        )

        let data = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(JSONSchema.self, from: data)

        XCTAssertEqual(decoded, schema)
        XCTAssertEqual(decoded.properties?["tags"]?.items?.schema.enumValues, ["a", "b"])
        XCTAssertEqual(decoded.properties?["nested"]?.properties?["count"]?.kind, .integer)
    }

    func testJSONSchemaBoxEqualityAndAccessor() {
        let box1 = JSONSchemaBox(.string())
        let box2 = JSONSchemaBox(.string())
        let box3 = JSONSchemaBox(.number())

        XCTAssertEqual(box1, box2)
        XCTAssertNotEqual(box1, box3)
        XCTAssertEqual(box1.schema, .string())
    }

    func testKindRawValuesRoundTrip() throws {
        for kind in [
            JSONSchema.Kind.object, .array, .string, .number, .integer, .boolean, .null
        ] {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(JSONSchema.Kind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }
}
