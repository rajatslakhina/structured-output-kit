/// Errors produced while extracting, validating, or decoding structured
/// output from raw LLM text.
public enum StructuredOutputError: Error, Sendable, Equatable {
    /// The raw text contained no recognizable JSON payload at all.
    case noJSONFound

    /// A JSON payload was found but does not satisfy the required schema
    /// (e.g. a required property was missing, or a value had the wrong
    /// primitive kind).
    case schemaMismatch(reason: String)

    /// A JSON payload was found and matched the schema shape, but Swift's
    /// `Decodable` still failed to decode it into the target type.
    case decodingFailed(reason: String)

    /// The model produced no usable output after the configured number of
    /// repair attempts.
    case maxRetriesExceeded(attempts: Int, lastError: String)

    /// A caller supplied an invalid argument (e.g. a non-positive
    /// `maxAttempts`). Thrown rather than trapping via `precondition` so
    /// callers can recover from a programming mistake instead of crashing.
    case invalidArgument(reason: String)

    public static func == (lhs: StructuredOutputError, rhs: StructuredOutputError) -> Bool {
        switch (lhs, rhs) {
        case (.noJSONFound, .noJSONFound):
            return true
        case let (.schemaMismatch(a), .schemaMismatch(b)):
            return a == b
        case let (.decodingFailed(a), .decodingFailed(b)):
            return a == b
        case let (.maxRetriesExceeded(a1, a2), .maxRetriesExceeded(b1, b2)):
            return a1 == b1 && a2 == b2
        case let (.invalidArgument(a), .invalidArgument(b)):
            return a == b
        default:
            return false
        }
    }
}

extension StructuredOutputError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .noJSONFound:
            return "No JSON payload could be found in the model's response."
        case let .schemaMismatch(reason):
            return "Response JSON did not match the expected schema: \(reason)"
        case let .decodingFailed(reason):
            return "Response JSON matched the schema shape but failed to decode: \(reason)"
        case let .maxRetriesExceeded(attempts, lastError):
            return "Gave up after \(attempts) attempt(s); last error: \(lastError)"
        case let .invalidArgument(reason):
            return "Invalid argument: \(reason)"
        }
    }
}
