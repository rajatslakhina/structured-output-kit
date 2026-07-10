/// Turns a ``JSONSchema`` into plain-language instructions to append to a
/// prompt, so a model knows exactly what shape to answer in.
///
/// This deliberately renders schemas as readable instructions rather than
/// raw JSON Schema documents — most providers follow a compact "answer with
/// JSON matching this shape" instruction at least as reliably as a formal
/// schema block, and it keeps this package independent of any one
/// provider's native structured-output API.
public enum PromptBuilder {
    /// Builds a "respond with JSON matching this shape" instruction block
    /// for `schema`, suitable for appending to a chat prompt.
    public static func instructions(for schema: JSONSchema, typeName: String = "the result") -> String {
        var lines = ["Respond with a single JSON value for \(typeName), matching exactly this shape:"]
        lines.append(render(schema, indent: ""))
        lines.append("Respond with ONLY the JSON value — no prose, no Markdown code fences.")
        return lines.joined(separator: "\n")
    }

    private static func render(_ schema: JSONSchema, indent: String) -> String {
        switch schema.kind {
        case .object:
            let properties = schema.properties ?? [:]
            let required = Set(schema.required ?? [])
            let childIndent = indent + "  "
            let fields = properties.sorted { $0.key < $1.key }.map { key, propertySchema -> String in
                let marker = required.contains(key) ? "" : " (optional)"
                let child = render(propertySchema, indent: childIndent)
                return "\(childIndent)\"\(key)\"\(marker): \(child)"
            }
            let body = fields.isEmpty ? "" : "\n" + fields.joined(separator: ",\n") + "\n\(indent)"
            return "{\(body)}"
        case .array:
            let element = schema.items.map { render($0.schema, indent: indent) } ?? "any"
            return "[ \(element), ... ]"
        case .string:
            if let enumValues = schema.enumValues, !enumValues.isEmpty {
                return "one of " + enumValues.map { "\"\($0)\"" }.joined(separator: " | ")
            }
            return describable("string", schema.description)
        case .number:
            return describable("number", schema.description)
        case .integer:
            return describable("integer", schema.description)
        case .boolean:
            return describable("true | false", schema.description)
        case .null:
            return "null"
        }
    }

    private static func describable(_ kind: String, _ description: String?) -> String {
        guard let description, !description.isEmpty else { return kind }
        return "\(kind) — \(description)"
    }
}
