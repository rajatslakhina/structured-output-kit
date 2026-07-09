import XCTest
@testable import StructuredOutputKit

final class PromptBuilderTests: XCTestCase {
    func testInstructionsIncludeHeaderTypeNameAndFooter() {
        let text = PromptBuilder.instructions(for: .string(), typeName: "a greeting")
        XCTAssertTrue(text.contains("a greeting"))
        XCTAssertTrue(text.contains("ONLY the JSON value"))
    }

    func testRendersStringWithoutDescription() {
        let text = PromptBuilder.instructions(for: .string())
        XCTAssertTrue(text.contains("string"))
    }

    func testRendersStringWithDescription() {
        let text = PromptBuilder.instructions(for: .string(description: "a name"))
        XCTAssertTrue(text.contains("string — a name"))
    }

    func testRendersStringEnum() {
        let text = PromptBuilder.instructions(for: .string(enumValues: ["a", "b"]))
        XCTAssertTrue(text.contains("\"a\" | \"b\""))
    }

    func testRendersNumberIntegerBooleanNull() {
        XCTAssertTrue(PromptBuilder.instructions(for: .number(description: "n")).contains("number — n"))
        XCTAssertTrue(PromptBuilder.instructions(for: .integer(description: "i")).contains("integer — i"))
        XCTAssertTrue(PromptBuilder.instructions(for: .boolean(description: "b")).contains("true | false — b"))
        XCTAssertTrue(PromptBuilder.instructions(for: JSONSchema(kind: .null)).contains("null"))
    }

    func testRendersArrayOfPrimitives() {
        let text = PromptBuilder.instructions(for: .array(of: .integer()))
        XCTAssertTrue(text.contains("[ integer, ... ]"))
    }

    func testRendersArrayWithNoItemSchemaAsAny() {
        let text = PromptBuilder.instructions(for: JSONSchema(kind: .array))
        XCTAssertTrue(text.contains("[ any, ... ]"))
    }

    func testRendersObjectWithRequiredAndOptionalFields() {
        let schema = JSONSchema.object(
            properties: [
                "name": .string(),
                "nickname": .string()
            ],
            required: ["name"]
        )
        let text = PromptBuilder.instructions(for: schema)
        XCTAssertTrue(text.contains("\"name\": string"))
        XCTAssertTrue(text.contains("\"nickname\" (optional): string"))
    }

    func testRendersEmptyObjectWithoutTrailingArtifacts() {
        let text = PromptBuilder.instructions(for: JSONSchema(kind: .object))
        XCTAssertTrue(text.contains("{}"))
    }

    func testRendersNestedObjectInsideArray() {
        let schema = JSONSchema.array(of: .object(properties: ["id": .integer()], required: ["id"]))
        let text = PromptBuilder.instructions(for: schema)
        XCTAssertTrue(text.contains("\"id\": integer"))
    }
}
