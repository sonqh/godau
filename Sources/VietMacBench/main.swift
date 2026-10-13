import Foundation
import Dispatch
import VietMacCore

struct Report: Encodable {
    let schemaVersion: Int
    let scope: String
    let buildConfiguration: String
    let os: String
    let architecture: String
    let logicalCPUCount: Int
    let samples: Int
    let warmup: Int
    let medianNanoseconds: UInt64
    let p95Nanoseconds: UInt64
    let p99Nanoseconds: UInt64
    let maximumNanoseconds: UInt64
    let checksum: Int
}

#if DEBUG
FileHandle.standardError.write(Data("Use a release build for performance evidence.\n".utf8))
exit(2)
#else
do {
    let pairs = [("a", "á"), ("tiêng", "tiếng"), ("ấ", "áa"), (String(repeating: "a", count: 63) + "o", String(repeating: "a", count: 63) + "ó")]
    let count = 10_000
    let warmup = 1_000
    var checksum = 0
    for i in 0..<warmup {
        let pair = pairs[i % pairs.count]
        checksum &+= try ReplacementPlan.compute(previous: pair.0, next: pair.1).deleteCount
    }
    var durations = [UInt64]()
    durations.reserveCapacity(count)
    for i in 0..<count {
        let pair = pairs[i % pairs.count]
        let start = DispatchTime.now().uptimeNanoseconds
        let plan = try ReplacementPlan.compute(previous: pair.0, next: pair.1)
        let end = DispatchTime.now().uptimeNanoseconds
        durations.append(end - start)
        checksum &+= plan.deleteCount + plan.insertion.utf16.count
    }
    durations.sort()
    func percentile(_ fraction: Double) -> UInt64 {
        durations[Int((Double(count - 1) * fraction).rounded(.up))]
    }
    let report = Report(
        schemaVersion: 1,
        scope: "replacement-planner-only",
        buildConfiguration: "release",
        os: ProcessInfo.processInfo.operatingSystemVersionString,
        architecture: {
            #if arch(arm64)
            return "arm64"
            #elseif arch(x86_64)
            return "x86_64"
            #else
            return "unknown"
            #endif
        }(),
        logicalCPUCount: ProcessInfo.processInfo.processorCount,
        samples: count,
        warmup: warmup,
        medianNanoseconds: percentile(0.5),
        p95Nanoseconds: percentile(0.95),
        p99Nanoseconds: percentile(0.99),
        maximumNanoseconds: durations.last!,
        checksum: checksum
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(report), as: UTF8.self))
} catch {
    FileHandle.standardError.write(Data("Benchmark failed: \(error)\n".utf8))
    exit(1)
}
#endif
