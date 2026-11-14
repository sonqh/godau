/// One field observation for native diagnosis. Metadata only: no document text or key identity.
public struct ObservationRecord: Encodable, Sendable {
    public let sequence: UInt64
    public let source: String
    public let role: String?
    public let elementHash: UInt?
    public let focusChanged: Bool
    public let reading: String
    public let caret: Int?
    public let length: Int?
    public let result: String
    public let keysSincePrevious: UInt32
    public let pendingAfter: Int
    public let settledAfter: Bool
}

/// Fixed-capacity ring filled on the owning run loop outside the key callback.
public struct ObservationTrace {
    public static let capacity = 512
    private var records: [ObservationRecord] = []
    private var next = 0
    private var sequence: UInt64 = 0

    public init() {
        records.reserveCapacity(Self.capacity)
    }

    mutating func append(source: String, inspection: FocusInspection, result: FieldObservation,
                         keysSincePrevious: UInt32, field: FieldContextTracker) {
        sequence &+= 1
        var caret: Int?
        var length: Int?
        let reading: String
        switch inspection.field {
        case .caret(let snapshot):
            reading = "caret"
            caret = snapshot.caret
            length = snapshot.length
        case .selection: reading = "selection"
        case .unavailable(let reason): reading = "unavailable:\(reason.rawValue)"
        }
        let record = ObservationRecord(sequence: sequence, source: source, role: inspection.role,
            elementHash: inspection.elementHash, focusChanged: inspection.changed, reading: reading,
            caret: caret, length: length, result: "\(result)", keysSincePrevious: keysSincePrevious,
            pendingAfter: field.pendingCount, settledAfter: field.isSettled)
        if records.count < Self.capacity { records.append(record) }
        else { records[next] = record }
        next = (next + 1) % Self.capacity
    }

    /// Oldest first.
    public var ordered: [ObservationRecord] {
        records.count < Self.capacity ? records : Array(records[next...] + records[..<next])
    }
}
