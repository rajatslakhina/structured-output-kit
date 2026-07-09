import XCTest
@testable import StructuredOutputKit

final class StructuredOutputErrorTests: XCTestCase {
    func testEqualityForEachCase() {
        XCTAssertEqual(StructuredOutputError.noJSONFound, .noJSONFound)
        XCTAssertEqual(StructuredOutputError.schemaMismatch(reason: "x"), .schemaMismatch(reason: "x"))
        XCTAssertNotEqual(StructuredOutputError.schemaMismatch(reason: "x"), .schemaMismatch(reason: "y"))
        XCTAssertEqual(StructuredOutputError.decodingFailed(reason: "x"), .decodingFailed(reason: "x"))
        XCTAssertNotEqual(StructuredOutputError.decodingFailed(reason: "x"), .decodingFailed(reason: "y"))
        XCTAssertEqual(
            StructuredOutputError.maxRetriesExceeded(attempts: 3, lastError: "x"),
            .maxRetriesExceeded(attempts: 3, lastError: "x")
        )
        XCTAssertNotEqual(
            StructuredOutputError.maxRetriesExceeded(attempts: 3, lastError: "x"),
            .maxRetriesExceeded(attempts: 2, lastError: "x")
        )
        XCTAssertEqual(StructuredOutputError.invalidArgument(reason: "x"), .invalidArgument(reason: "x"))
        XCTAssertNotEqual(StructuredOutputError.invalidArgument(reason: "x"), .invalidArgument(reason: "y"))
    }

    func testEqualityAcrossDifferentCasesIsFalse() {
        XCTAssertNotEqual(StructuredOutputError.noJSONFound, .schemaMismatch(reason: "x"))
        XCTAssertNotEqual(StructuredOutputError.schemaMismatch(reason: "x"), .decodingFailed(reason: "x"))
        XCTAssertNotEqual(
            StructuredOutputError.decodingFailed(reason: "x"),
            .maxRetriesExceeded(attempts: 1, lastError: "x")
        )
        XCTAssertNotEqual(
            StructuredOutputError.maxRetriesExceeded(attempts: 1, lastError: "x"),
            .invalidArgument(reason: "x")
        )
    }

    func testDescriptionsAreHumanReadable() {
        XCTAssertEqual(
            StructuredOutputError.noJSONFound.description,
            "No JSON payload could be found in the model's response."
        )
        XCTAssertTrue(StructuredOutputError.schemaMismatch(reason: "missing foo").description.contains("missing foo"))
        XCTAssertTrue(StructuredOutputError.decodingFailed(reason: "bad type").description.contains("bad type"))
        let maxRetries = StructuredOutputError.maxRetriesExceeded(attempts: 2, lastError: "oops").description
        XCTAssertTrue(maxRetries.contains("2"))
        XCTAssertTrue(maxRetries.contains("oops"))
        XCTAssertTrue(StructuredOutputError.invalidArgument(reason: "bad value").description.contains("bad value"))
    }
}
