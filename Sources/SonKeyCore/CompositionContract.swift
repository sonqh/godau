/// Semantic input. ASCII letter values preserve the case of the event text.
public enum CompositionInput: Equatable, Sendable {
    case asciiLetter(UInt8)
    case backspace
    case boundary
    case invalidate
}

/// A context identifier supplied by the macOS adapter, not by a global engine.
public struct ContextToken: Equatable, Sendable {
    public let generation: UInt64

    public init(generation: UInt64) {
        self.generation = generation
    }
}

/// The future reducer returns an explicit replacement including any literal key.
/// These contracts do not implement Telex or establish native text ownership.
public enum CompositionIntent: Equatable, Sendable {
    case passThrough
    case replace(previous: String, next: String, context: ContextToken)
}
