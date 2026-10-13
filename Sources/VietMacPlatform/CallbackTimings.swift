import Foundation

public struct CallbackTimingReport: Encodable, Sendable {
    public let scope = "event-tap-callback-own-work"
    public let acknowledgement = "Event posting does not acknowledge client insertion"
    public let totalSamples: UInt64
    public let retainedSamples: Int
    public let capacity: Int
    public let medianNanoseconds: UInt64?
    public let p95Nanoseconds: UInt64?
    public let p99Nanoseconds: UInt64?
    public let maximumNanoseconds: UInt64?
}

/// Fixed storage; sorting/encoding happens only in snapshot/export.
public struct CallbackTimings {
    private var samples = Array(repeating: UInt64(0), count: 1024)
    private var index = 0
    private var filled = 0
    private var total: UInt64 = 0

    public init() {}

    public mutating func record(_ nanoseconds: UInt64) {
        samples[index] = nanoseconds
        index = (index + 1) % samples.count
        filled = min(filled + 1, samples.count)
        total &+= 1
    }

    public func snapshot() -> CallbackTimingReport {
        let values = samples.prefix(filled).sorted()
        func percentile(_ fraction: Double) -> UInt64? {
            guard !values.isEmpty else { return nil }
            return values[Int((Double(values.count - 1) * fraction).rounded(.up))]
        }
        return CallbackTimingReport(totalSamples: total, retainedSamples: filled, capacity: samples.count,
            medianNanoseconds: percentile(0.5), p95Nanoseconds: percentile(0.95),
            p99Nanoseconds: percentile(0.99), maximumNanoseconds: values.last)
    }
}
