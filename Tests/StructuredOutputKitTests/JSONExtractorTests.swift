import XCTest
@testable import StructuredOutputKit

final class JSONExtractorTests: XCTestCase {
    func testExtractsWhenTextIsExactlyJSONObject() {
        let text = #"{"a": 1}"#
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), text)
    }

    func testExtractsWhenTextIsExactlyJSONArray() {
        let text = "[1, 2, 3]"
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), text)
    }

    func testTrimsWhitespaceAroundCompleteJSON() {
        let text = "\n  {\"a\": 1}  \n"
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), "{\"a\": 1}")
    }

    func testReturnsNilForEmptyString() {
        XCTAssertNil(JSONExtractor.extractJSONSubstring(from: "   \n  "))
    }

    func testReturnsNilWhenNoJSONPresent() {
        XCTAssertNil(JSONExtractor.extractJSONSubstring(from: "Sorry, I can't help with that."))
    }

    func testExtractsFromJSONFencedCodeBlock() {
        let text = """
        Here you go:
        ```json
        {"city": "Pune", "temp": 30}
        ```
        Anything else?
        """
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), #"{"city": "Pune", "temp": 30}"#)
    }

    func testExtractsFromBareFencedCodeBlock() {
        let text = """
        ```
        {"ok": true}
        ```
        """
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), #"{"ok": true}"#)
    }

    func testExtractsFromUppercaseJSONFence() {
        let text = "```JSON\n{\"ok\": true}\n```"
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), #"{"ok": true}"#)
    }

    func testExtractsBalancedObjectEmbeddedInProseWithoutFences() {
        let text = #"The result is {"a": 1, "b": [1, 2, 3]} — let me know if you need more."#
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), #"{"a": 1, "b": [1, 2, 3]}"#)
    }

    func testExtractsFirstOfMultipleObjectsInProse() {
        let text = #"First: {"a": 1}. Second: {"b": 2}."#
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), #"{"a": 1}"#)
    }

    func testHandlesBracesInsideStringLiteralsWithoutBreakingBalance() {
        let text = #"{"note": "use { and } carefully", "n": 1}"#
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), text)
    }

    func testHandlesEscapedQuotesInsideStrings() {
        let text = #"{"note": "she said \"hi\"", "n": 1}"#
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), text)
    }

    func testHandlesNestedObjectsAndArrays() {
        let text = #"prefix {"outer": {"inner": [1, {"deep": true}]}} suffix"#
        XCTAssertEqual(
            JSONExtractor.extractJSONSubstring(from: text),
            #"{"outer": {"inner": [1, {"deep": true}]}}"#
        )
    }

    func testReturnsNilForUnbalancedBraces() {
        XCTAssertNil(JSONExtractor.extractJSONSubstring(from: "this { is not json"))
    }

    func testCompleteLookingTextThatIsInvalidJSONFallsThroughToNil() {
        // Starts with `{` and ends with `}` but is not valid JSON, and has no
        // valid balanced span either — every extraction strategy should fail.
        XCTAssertNil(JSONExtractor.extractJSONSubstring(from: "{not valid at all"))
    }

    func testExtractJSONDataThrowsWhenNothingFound() {
        XCTAssertThrowsError(try JSONExtractor.extractJSONData(from: "no json here")) { error in
            XCTAssertEqual(error as? StructuredOutputError, .noJSONFound)
        }
    }

    func testExtractJSONDataReturnsDecodableData() throws {
        let data = try JSONExtractor.extractJSONData(from: #"{"a": 1}"#)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value, .object(["a": .number(1)]))
    }

    // MARK: - Fallthrough between strategies

    func testUnclosedFenceFallsThroughToBalancedSpanStrategy() {
        // Opens a ```json fence but never closes it, so `fencedJSONBlock`
        // can't find a matching end marker for any candidate fence marker
        // and must fall through; the balanced-span scan then finds the
        // object directly.
        let text = "```json\n{\"a\": 1}"
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), #"{"a": 1}"#)
    }

    func testFencedContentThatIsNotValidJSONIsRejectedAndFallsThrough() {
        // The fenced block is well-formed (open + close markers both
        // present) but its content isn't valid JSON, so it must be
        // rejected rather than returned; extraction should still recover
        // by finding the balanced object later in the text.
        let text = """
        ```json
        not actually json
        ```
        Fallback: {"ok": true}
        """
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), #"{"ok": true}"#)
    }

    func testBalancedButInvalidSpanIsRejectedRatherThanReturned() {
        // `{oops: true}` has balanced braces but an unquoted key, so it is
        // not valid JSON. There's nothing else in the text to recover
        // with, so extraction must give up rather than returning the
        // structurally-balanced-but-invalid span.
        XCTAssertNil(JSONExtractor.extractJSONSubstring(from: "{oops: true}"))
    }

    func testHandlesEscapedQuoteWhileScanningSpanEmbeddedInProse() {
        // Every existing escaped-quote fixture is complete, valid JSON on
        // its own, so it's matched by the whole-string strategy before the
        // manual balanced-span scanner (which does its own escape
        // tracking) ever runs. Wrapping it in prose forces the scan path,
        // exercising the scanner's backslash-escape handling directly.
        let text = #"Prefix {"a": "x\"y"} Suffix"#
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), #"{"a": "x\"y"}"#)
    }

    func testBalancedButInvalidSpanSkipsToALaterValidSpan() {
        // The first balanced span found (starting from the first `{`)
        // never becomes valid JSON no matter how far it's extended, so the
        // scan must abandon that starting point and find the later,
        // independently-valid object instead.
        let text = #"Bad: {oops: true} Good: {"ok": true}"#
        XCTAssertEqual(JSONExtractor.extractJSONSubstring(from: text), #"{"ok": true}"#)
    }
}
