import XCTest
@testable import StructuredOutputKit

private struct Greeting: Decodable, Equatable, JSONSchemaConvertible {
    let message: String

    static var jsonSchema: JSONSchema {
        .object(properties: ["message": .string()], required: ["message"])
    }
}

/// A schema deliberately looser than the concrete type it describes, so a
/// value can pass schema validation yet still fail to decode into `Self`.
/// This is what makes the `T`-decode failure branch in
/// `StructuredOutputDecoder.decode(_:from:)` reachable in tests.
private struct LooselySchemadGreeting: Decodable, JSONSchemaConvertible {
    let message: String

    static var jsonSchema: JSONSchema { JSONSchema(kind: .object) }
}

final class StructuredOutputDecoderTests: XCTestCase {
    // MARK: - Single-shot decode(_:from:)

    func testDecodesCleanJSON() async throws {
        let decoder = StructuredOutputDecoder()
        let result = try await decoder.decode(Greeting.self, from: #"{"message": "hi"}"#)
        XCTAssertEqual(result, Greeting(message: "hi"))
    }

    func testDecodesFencedJSONWithProse() async throws {
        let decoder = StructuredOutputDecoder()
        let text = """
        Sure thing:
        ```json
        {"message": "hello"}
        ```
        """
        let result = try await decoder.decode(Greeting.self, from: text)
        XCTAssertEqual(result, Greeting(message: "hello"))
    }

    func testThrowsNoJSONFoundWhenTextHasNoJSON() async {
        let decoder = StructuredOutputDecoder()
        do {
            _ = try await decoder.decode(Greeting.self, from: "no json at all")
            XCTFail("expected noJSONFound to be thrown")
        } catch {
            XCTAssertEqual(error as? StructuredOutputError, .noJSONFound)
        }
    }

    func testThrowsSchemaMismatchWhenRequiredFieldMissing() async {
        let decoder = StructuredOutputDecoder()
        do {
            _ = try await decoder.decode(Greeting.self, from: "{}")
            XCTFail("expected schemaMismatch to be thrown")
        } catch {
            guard case .schemaMismatch(let reason) = error as? StructuredOutputError else {
                return XCTFail("expected schemaMismatch, got \(error)")
            }
            XCTAssertEqual(reason, "$.message is required but missing")
        }
    }

    func testThrowsDecodingFailedWhenSchemaPassesButConcreteTypeDecodeFails() async {
        // The schema for `LooselySchemadGreeting` accepts any object, so
        // `{"other": 1}` clears schema validation — but the concrete type
        // requires a `message` string, so the final `Decodable` decode
        // fails. This is what actually exercises the shared
        // `decodingFailed` catch path (see the comment in
        // `StructuredOutputDecoder.decode(_:from:)` for why it's shared
        // rather than duplicated per decode attempt).
        let decoder = StructuredOutputDecoder()
        do {
            _ = try await decoder.decode(LooselySchemadGreeting.self, from: #"{"other": 1}"#)
            XCTFail("expected decodingFailed to be thrown")
        } catch {
            guard case .decodingFailed(let reason) = error as? StructuredOutputError else {
                return XCTFail("expected decodingFailed, got \(error)")
            }
            XCTAssertTrue(reason.contains("message"), "expected reason to mention the missing key, got: \(reason)")
        }
    }

    // MARK: - Retrying decode(_:maxAttempts:generate:)

    func testSucceedsOnFirstAttempt() async throws {
        let decoder = StructuredOutputDecoder()
        let result = try await decoder.decode(Greeting.self) { previousText, previousError in
            XCTAssertNil(previousText)
            XCTAssertNil(previousError)
            return #"{"message": "first try"}"#
        }
        XCTAssertEqual(result, Greeting(message: "first try"))
    }

    func testRecoversOnSecondAttemptUsingPreviousErrorContext() async throws {
        let decoder = StructuredOutputDecoder()
        nonisolated(unsafe) var callCount = 0
        let result = try await decoder.decode(Greeting.self, maxAttempts: 3) { previousText, previousError in
            callCount += 1
            if callCount == 1 {
                XCTAssertNil(previousText)
                XCTAssertNil(previousError)
                return "not json"
            } else {
                XCTAssertEqual(previousText, "not json")
                XCTAssertEqual(previousError, .noJSONFound)
                return #"{"message": "recovered"}"#
            }
        }
        XCTAssertEqual(result, Greeting(message: "recovered"))
        XCTAssertEqual(callCount, 2)
    }

    func testExhaustsAllAttemptsAndThrowsMaxRetriesExceeded() async {
        let decoder = StructuredOutputDecoder()
        nonisolated(unsafe) var callCount = 0
        do {
            _ = try await decoder.decode(Greeting.self, maxAttempts: 3) { _, _ in
                callCount += 1
                return "still not json"
            }
            XCTFail("expected maxRetriesExceeded to be thrown")
        } catch {
            guard case .maxRetriesExceeded(let attempts, let lastError) = error as? StructuredOutputError else {
                return XCTFail("expected maxRetriesExceeded, got \(error)")
            }
            XCTAssertEqual(attempts, 3)
            XCTAssertTrue(lastError.contains("No JSON payload"), "unexpected lastError: \(lastError)")
        }
        XCTAssertEqual(callCount, 3)
    }

    func testSingleAttemptFailureThrowsImmediatelyWithoutRecursing() async {
        let decoder = StructuredOutputDecoder()
        nonisolated(unsafe) var callCount = 0
        do {
            _ = try await decoder.decode(Greeting.self, maxAttempts: 1) { _, _ in
                callCount += 1
                return "nope"
            }
            XCTFail("expected maxRetriesExceeded to be thrown")
        } catch {
            guard case .maxRetriesExceeded(let attempts, _) = error as? StructuredOutputError else {
                return XCTFail("expected maxRetriesExceeded, got \(error)")
            }
            XCTAssertEqual(attempts, 1)
        }
        XCTAssertEqual(callCount, 1)
    }

    func testThrowsInvalidArgumentForNonPositiveMaxAttemptsWithoutCallingGenerate() async {
        let decoder = StructuredOutputDecoder()
        nonisolated(unsafe) var callCount = 0
        do {
            _ = try await decoder.decode(Greeting.self, maxAttempts: 0) { _, _ in
                callCount += 1
                return #"{"message": "unreachable"}"#
            }
            XCTFail("expected invalidArgument to be thrown")
        } catch {
            guard case .invalidArgument(let reason) = error as? StructuredOutputError else {
                return XCTFail("expected invalidArgument, got \(error)")
            }
            XCTAssertTrue(reason.contains("0"))
        }
        XCTAssertEqual(callCount, 0, "generate must not be called when maxAttempts is invalid")
    }

    func testGenerateThrowingNonStructuredErrorPropagatesWithoutRetry() async {
        struct GenerateFailure: Error, Equatable {}
        let decoder = StructuredOutputDecoder()
        nonisolated(unsafe) var callCount = 0
        do {
            _ = try await decoder.decode(Greeting.self, maxAttempts: 3) { _, _ in
                callCount += 1
                throw GenerateFailure()
            }
            XCTFail("expected GenerateFailure to propagate")
        } catch {
            XCTAssertTrue(error is GenerateFailure)
        }
        XCTAssertEqual(callCount, 1)
    }
}
