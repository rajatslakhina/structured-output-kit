import Foundation

/// Pulls a single JSON payload out of raw LLM text.
///
/// Models rarely answer with *only* JSON: they wrap it in a Markdown code
/// fence, or add a sentence of preamble/postamble around it. `JSONExtractor`
/// tries, in order, the cheapest interpretation first:
/// 1. The whole trimmed string is already valid JSON.
/// 2. There is a ```json ... ``` (or bare ``` ... ```) fenced block.
/// 3. There is a balanced `{...}` or `[...]` span somewhere in the text.
public enum JSONExtractor {
    /// Returns the raw JSON substring found in `text`, or `nil` if nothing
    /// resembling a JSON object/array could be located.
    public static func extractJSONSubstring(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if looksLikeCompleteJSON(trimmed) {
            return trimmed
        }

        if let fenced = fencedJSONBlock(in: trimmed) {
            return fenced
        }

        if let balanced = firstBalancedJSONSpan(in: trimmed) {
            return balanced
        }

        return nil
    }

    /// Extracts and parses `text` into `Data` ready for `JSONDecoder`.
    public static func extractJSONData(from text: String) throws -> Data {
        guard let substring = extractJSONSubstring(from: text) else {
            throw StructuredOutputError.noJSONFound
        }
        return Data(substring.utf8)
    }

    // MARK: - Private helpers

    private static func looksLikeCompleteJSON(_ text: String) -> Bool {
        let looksLikeObject = text.hasPrefix("{") && text.hasSuffix("}")
        let looksLikeArray = text.hasPrefix("[") && text.hasSuffix("]")
        guard looksLikeObject || looksLikeArray else { return false }
        return isValidJSON(text)
    }

    private static func fencedJSONBlock(in text: String) -> String? {
        let fenceMarkers = ["```json", "```JSON", "```"]
        for marker in fenceMarkers {
            guard let startRange = text.range(of: marker) else { continue }
            let afterMarker = text[startRange.upperBound...]
            guard let endRange = afterMarker.range(of: "```") else { continue }
            let candidate = afterMarker[..<endRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty, isValidJSON(candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func firstBalancedJSONSpan(in text: String) -> String? {
        let openers: [Character: Character] = ["{": "}", "[": "]"]
        let characters = Array(text)

        for (index, character) in characters.enumerated() {
            guard let closer = openers[character] else { continue }
            var depth = 0
            var inString = false
            var previousWasEscape = false

            for cursor in index..<characters.count {
                let current = characters[cursor]

                if inString {
                    if current == "\"" && !previousWasEscape {
                        inString = false
                    }
                    previousWasEscape = (current == "\\") && !previousWasEscape
                    continue
                }

                switch current {
                case "\"":
                    inString = true
                    previousWasEscape = false
                case character:
                    depth += 1
                case closer:
                    depth -= 1
                    if depth == 0 {
                        let span = String(characters[index...cursor])
                        if isValidJSON(span) {
                            return span
                        }
                    }
                default:
                    break
                }
            }
        }
        return nil
    }

    private static func isValidJSON(_ candidate: String) -> Bool {
        let data = Data(candidate.utf8)
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }
}
