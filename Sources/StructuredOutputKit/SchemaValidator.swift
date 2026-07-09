/// Structural validation of a decoded ``JSONValue`` against a
/// ``JSONSchema`` description.
///
/// This intentionally checks *shape* (right primitive kind, required keys
/// present, array elements match) rather than full JSON Schema semantics —
/// it exists to give a clear, early "the model answered with the wrong
/// shape" error before handing the payload to `Decodable`, which otherwise
/// tends to produce much less actionable error messages.
public enum SchemaValidator {
    /// Returns a human-readable description of the first mismatch found
    /// between `value` and `schema`, or `nil` if `value` satisfies `schema`.
    public static func firstMismatch(of value: JSONValue, against schema: JSONSchema, path: String = "$") -> String? {
        switch (schema.kind, value) {
        case (.object, .object(let object)):
            return objectMismatch(of: object, against: schema, path: path)
        case (.array, .array(let array)):
            return arrayMismatch(of: array, against: schema, path: path)
        case (.string, .string(let string)):
            return enumMismatch(of: string, against: schema, path: path)
        case (.number, .number):
            return nil
        case (.integer, .number(let number)):
            return number == number.rounded(.towardZero) ? nil : "\(path) expected an integer"
        case (.boolean, .bool):
            return nil
        case (.null, .null):
            return nil
        default:
            return "\(path) expected \(schema.kind.rawValue), got \(kindName(of: value))"
        }
    }

    // MARK: - Composite kinds

    private static func objectMismatch(
        of object: [String: JSONValue],
        against schema: JSONSchema,
        path: String
    ) -> String? {
        for key in schema.required ?? [] where object[key] == nil {
            return "\(path).\(key) is required but missing"
        }

        guard let properties = schema.properties else { return nil }

        for (key, propertySchema) in properties {
            guard let propertyValue = object[key] else { continue }
            if let mismatch = firstMismatch(of: propertyValue, against: propertySchema, path: "\(path).\(key)") {
                return mismatch
            }
        }
        return nil
    }

    private static func arrayMismatch(of array: [JSONValue], against schema: JSONSchema, path: String) -> String? {
        guard let itemSchema = schema.items?.schema else { return nil }

        for (index, element) in array.enumerated() {
            if let mismatch = firstMismatch(of: element, against: itemSchema, path: "\(path)[\(index)]") {
                return mismatch
            }
        }
        return nil
    }

    private static func enumMismatch(of string: String, against schema: JSONSchema, path: String) -> String? {
        guard let allowed = schema.enumValues else { return nil }
        return allowed.contains(string) ? nil : "\(path) expected one of \(allowed), got \(string)"
    }

    private static func kindName(of value: JSONValue) -> String {
        switch value {
        case .object: return "object"
        case .array: return "array"
        case .string: return "string"
        case .number: return "number"
        case .bool: return "boolean"
        case .null: return "null"
        }
    }
}
