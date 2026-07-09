/// A minimal, `Sendable` representation of a JSON Schema node.
///
/// `JSONSchema` is intentionally small: it covers the subset of JSON Schema
/// that is useful for describing the *shape* an LLM should answer in, not
/// full JSON Schema validation semantics (no `$ref`, no combinators).
public struct JSONSchema: Sendable, Equatable, Codable {
    /// The primitive JSON types a schema node can describe.
    public enum Kind: String, Sendable, Equatable, Codable {
        case object
        case array
        case string
        case number
        case integer
        case boolean
        case null
    }

    public var kind: Kind
    public var description: String?
    /// Property name -> schema, for `.object` kinds.
    public var properties: [String: JSONSchema]?
    /// Which of `properties` are required, for `.object` kinds.
    public var required: [String]?
    /// Element schema, for `.array` kinds.
    public var items: JSONSchemaBox?
    /// Restricts a `.string` kind to one of these literal values.
    public var enumValues: [String]?

    public init(
        kind: Kind,
        description: String? = nil,
        properties: [String: JSONSchema]? = nil,
        required: [String]? = nil,
        items: JSONSchema? = nil,
        enumValues: [String]? = nil
    ) {
        self.kind = kind
        self.description = description
        self.properties = properties
        self.required = required
        self.items = items.map(JSONSchemaBox.init)
        self.enumValues = enumValues
    }

    /// Convenience constructor for an `.object` schema.
    public static func object(
        properties: [String: JSONSchema],
        required: [String] = [],
        description: String? = nil
    ) -> JSONSchema {
        JSONSchema(
            kind: .object,
            description: description,
            properties: properties,
            required: required
        )
    }

    /// Convenience constructor for an `.array` schema.
    public static func array(of item: JSONSchema, description: String? = nil) -> JSONSchema {
        JSONSchema(kind: .array, description: description, items: item)
    }

    /// Convenience constructor for a `.string` schema.
    public static func string(description: String? = nil, enumValues: [String]? = nil) -> JSONSchema {
        JSONSchema(kind: .string, description: description, enumValues: enumValues)
    }

    /// Convenience constructor for a `.number` schema.
    public static func number(description: String? = nil) -> JSONSchema {
        JSONSchema(kind: .number, description: description)
    }

    /// Convenience constructor for an `.integer` schema.
    public static func integer(description: String? = nil) -> JSONSchema {
        JSONSchema(kind: .integer, description: description)
    }

    /// Convenience constructor for a `.boolean` schema.
    public static func boolean(description: String? = nil) -> JSONSchema {
        JSONSchema(kind: .boolean, description: description)
    }
}

/// A reference-type box so `JSONSchema` can nest (arrays of objects, objects
/// containing arrays, and so on) despite being a value type itself — a
/// `struct` cannot directly store another instance of itself, so `items`
/// goes through this immutable class-based indirection instead.
public final class JSONSchemaBox: Equatable, Codable, @unchecked Sendable {
    public let schema: JSONSchema

    public init(_ schema: JSONSchema) {
        self.schema = schema
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.schema = try container.decode(JSONSchema.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(schema)
    }

    public static func == (lhs: JSONSchemaBox, rhs: JSONSchemaBox) -> Bool {
        lhs.schema == rhs.schema
    }
}
