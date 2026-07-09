import StructuredOutputKit

// A response shape you'd ask a routed LLM call (e.g. through
// ProviderGatewayKit) to answer in.
struct WeatherReport: Decodable, Equatable, JSONSchemaConvertible {
    let city: String
    let temperatureCelsius: Double
    let conditions: String
    let isRainExpected: Bool

    static var jsonSchema: JSONSchema {
        .object(
            properties: [
                "city": .string(description: "The city the report is for"),
                "temperatureCelsius": .number(description: "Current temperature in Celsius"),
                "conditions": .string(enumValues: ["clear", "cloudy", "rain", "storm"]),
                "isRainExpected": .boolean(description: "Whether rain is expected in the next few hours")
            ],
            required: ["city", "temperatureCelsius", "conditions", "isRainExpected"]
        )
    }
}

@main
struct StructuredOutputDemo {
    static func main() async {
        print("== StructuredOutputKit demo ==")
        print()
        print(PromptBuilder.instructions(for: WeatherReport.jsonSchema, typeName: "a WeatherReport"))
        print()

        let decoder = StructuredOutputDecoder()

        // 1) A clean, direct JSON answer.
        await report(
            label: "claude-sonnet (clean JSON)",
            decoder: decoder,
            text: #"""
            {"city": "Bengaluru", "temperatureCelsius": 27.5, "conditions": "cloudy", "isRainExpected": true}
            """#
        )

        // 2) An answer wrapped in prose + a Markdown fence, as models often do.
        await report(
            label: "gpt-4o (fenced JSON with prose)",
            decoder: decoder,
            text: #"""
            Here is the current weather report you asked for:
            ```json
            {"city": "Mumbai", "temperatureCelsius": 31.0, "conditions": "storm", "isRainExpected": true}
            ```
            Let me know if you need an hourly breakdown.
            """#
        )

        // 3) A malformed first attempt (missing a required field), repaired on retry.
        await reportWithRetry(label: "gpt-4o-mini (self-repairing)", decoder: decoder)

        print()
        print("Demo complete: 3/3 responses successfully decoded into WeatherReport.")
    }

    private static func report(label: String, decoder: StructuredOutputDecoder, text: String) async {
        do {
            let value = try await decoder.decode(WeatherReport.self, from: text)
            print("[\(label)] decoded: \(value)")
        } catch {
            print("[\(label)] FAILED: \(error)")
        }
    }

    private static func reportWithRetry(label: String, decoder: StructuredOutputDecoder) async {
        // Simulates: the first response is missing "isRainExpected"; the
        // caller's `generate` closure "re-prompts" the model on failure
        // (here, just returns a corrected canned string) using only the
        // `previousError` the decoder hands back — no external mutable
        // state needed, which keeps the closure trivially `Sendable`.
        let malformedResponse = #"{"city": "Chennai", "temperatureCelsius": 33.2, "conditions": "clear"}"#
        let correctedResponse = #"""
        {"city": "Chennai", "temperatureCelsius": 33.2, "conditions": "clear", "isRainExpected": false}
        """#

        do {
            let value = try await decoder.decode(WeatherReport.self, maxAttempts: 3) { _, previousError in
                guard let previousError else {
                    return malformedResponse
                }
                print("[\(label)] previous attempt was rejected: \(previousError)")
                return correctedResponse
            }
            print("[\(label)] decoded after a repair round-trip: \(value)")
        } catch {
            print("[\(label)] FAILED: \(error)")
        }
    }
}
