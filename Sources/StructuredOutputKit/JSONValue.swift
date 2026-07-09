/// A minimal, `Decodable`-native representation of "any JSON value".
///
/// `JSONDecoder` itself already knows, unambiguously, whether a token in the
/// source JSON was `true`/`false`, a number, a string, `null`, an array, or
/// an object — that information is only lost if you go through
/// `JSONSerialization`'s `Any`/`NSNumber` bridging, which behaves subtly
/// differently across platforms. Decoding into `JSONValue` instead keeps
/// that distinction intact everywhere this package runs.
public enum JSONValue: Sendable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
}

extension JSONValue: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else {
            // No wrapping/re-throwing here: object is the last remaining
            // possibility for any well-formed JSON token (every other shape
            // was already ruled out above), so if this also fails, the
            // container's own `DecodingError` already describes exactly
            // what went wrong — there's nothing a synthesized fallback
            // error could add.
            self = .object(try container.decode([String: JSONValue].self))
        }
    }
}

extension JSONValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}
