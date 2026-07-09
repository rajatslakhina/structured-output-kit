/// A type that can describe its own expected JSON shape.
///
/// Conform your `Decodable` response models to `JSONSchemaConvertible` so
/// ``PromptBuilder`` can tell the model exactly what shape to answer in, and
/// so ``StructuredOutputDecoder`` can validate a candidate JSON payload
/// against that shape before attempting to decode it.
public protocol JSONSchemaConvertible {
    /// The JSON Schema describing instances of this type.
    static var jsonSchema: JSONSchema { get }
}
