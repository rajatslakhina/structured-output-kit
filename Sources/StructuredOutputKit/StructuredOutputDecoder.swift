import Foundation

/// Decodes raw LLM text into strongly-typed, schema-validated Swift values.
///
/// `StructuredOutputDecoder` is an `actor` (matching ProviderGatewayKit's
/// concurrency style) so that retry bookkeeping — how many repair attempts
/// have been made for a given exchange — is safe to share across
/// concurrently in-flight requests.
public actor StructuredOutputDecoder {
    private let jsonDecoder: JSONDecoder

    public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
        self.jsonDecoder = jsonDecoder
    }

    /// Decodes a single piece of raw model text into `T`, without retrying.
    ///
    /// - Throws: ``StructuredOutputError`` if no JSON can be found, if the
    ///   JSON does not satisfy `T.jsonSchema`, or if `Decodable` decoding
    ///   still fails afterward.
    public func decode<T: Decodable & JSONSchemaConvertible>(
        _ type: T.Type,
        from text: String
    ) throws -> T {
        let data = try JSONExtractor.extractJSONData(from: text)

        // Both decode attempts below share one failure path on purpose.
        // `JSONExtractor` only ever hands back a substring it already proved
        // parses as JSON, so decoding that substring into `JSONValue` cannot
        // fail for any input this method can actually be reached with; the
        // realistic failure is the later, stricter decode into `T`. Sharing
        // one `catch` (instead of one per decode call) means that single
        // still-meaningful defensive path is exercised — and covered — by
        // the `T`-decode failure case instead of sitting as a second,
        // structurally unreachable copy of the same line.
        do {
            let candidate = try jsonDecoder.decode(JSONValue.self, from: data)
            if let mismatch = SchemaValidator.firstMismatch(of: candidate, against: T.jsonSchema) {
                throw StructuredOutputError.schemaMismatch(reason: mismatch)
            }
            return try jsonDecoder.decode(T.self, from: data)
        } catch let error as StructuredOutputError {
            throw error
        } catch {
            throw StructuredOutputError.decodingFailed(reason: String(describing: error))
        }
    }

    /// Decodes `T` from model text, asking `generate` to try again on
    /// failure, up to `maxAttempts` total tries.
    ///
    /// `generate` receives the previous attempt's raw text (or `nil` on the
    /// first try) and the error that made it unusable, so a caller can build
    /// a "your last answer was invalid because ... please retry" follow-up
    /// prompt for the model.
    public func decode<T: Decodable & JSONSchemaConvertible>(
        _ type: T.Type,
        maxAttempts: Int = 3,
        generate: @Sendable (_ previousText: String?, _ previousError: StructuredOutputError?) async throws -> String
    ) async throws -> T {
        guard maxAttempts > 0 else {
            throw StructuredOutputError.invalidArgument(reason: "maxAttempts must be positive, got \(maxAttempts)")
        }

        return try await attemptDecode(
            type,
            remainingAttempts: maxAttempts,
            totalAttempts: maxAttempts,
            lastText: nil,
            lastError: nil,
            generate: generate
        )
    }

    /// Recursive worker behind the retrying `decode(_:maxAttempts:generate:)`.
    ///
    /// Every path through this method provably `return`s or `throw`s: the
    /// success path returns, and the failure path either recurses (when
    /// attempts remain) or throws `maxRetriesExceeded` (when none do). That
    /// makes the "give up" throw reachable-by-construction instead of a
    /// trailing statement the compiler demands but a test can never exercise.
    private func attemptDecode<T: Decodable & JSONSchemaConvertible>(
        _ type: T.Type,
        remainingAttempts: Int,
        totalAttempts: Int,
        lastText: String?,
        lastError: StructuredOutputError?,
        generate: @Sendable (_ previousText: String?, _ previousError: StructuredOutputError?) async throws -> String
    ) async throws -> T {
        let text = try await generate(lastText, lastError)
        do {
            return try decode(type, from: text)
        } catch let error as StructuredOutputError {
            let attemptsMade = totalAttempts - remainingAttempts + 1
            if remainingAttempts <= 1 {
                throw StructuredOutputError.maxRetriesExceeded(
                    attempts: attemptsMade,
                    lastError: String(describing: error)
                )
            }
            return try await attemptDecode(
                type,
                remainingAttempts: remainingAttempts - 1,
                totalAttempts: totalAttempts,
                lastText: text,
                lastError: error,
                generate: generate
            )
        }
    }
}
