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
/// `--engine`: the complete composition reducer per semantic event (TelexComposer plus the replacement
/// plan for a changed word), over a workload of Vietnamese words, escapes, Backspace, and boundaries.
func engineReport() throws -> (scope: String, samples: [UInt64], warmup: Int, checksum: Int) {
    let words = ["tieengs", "Vieetj", "laf", "ngoon", "nguwx", "cuar", "nguowif", "dduowngf", "hoafn", "khuyur",
                 "thuowr", "quys", "gif", "aasa", "asss", "windows", "the", "quick", "brown", "fox"]
    // Events: letters, a Backspace after every seventh word, and a boundary after each word.
    var events: [UInt8] = []
    for (index, word) in words.enumerated() {
        events += Array(word.utf8)
        if index % 7 == 6 { events.append(8) }
        events.append(32)
    }
    let count = 10_000
    let warmup = 1_000
    var composer = TelexComposer()
    var checksum = 0
    var durations = [UInt64]()
    durations.reserveCapacity(count)
    func step(_ event: UInt8) throws -> Int {
        switch event {
        case 32:
            composer.reset()
            return 1
        case 8:
            composer.backspace()
            return composer.letters.count
        default:
            let before = composer.text
            guard case .text(let after) = composer.input(event) else { composer.reset(); return 0 }
            if after.utf8.count != before.utf8.count + 1 || !after.hasPrefix(before) {
                return try ReplacementPlan.compute(previous: before, next: after).deleteCount + after.utf8.count
            }
            return after.utf8.count
        }
    }
    for i in 0..<warmup { checksum &+= try step(events[i % events.count]) }
    for i in 0..<count {
        let event = events[(warmup + i) % events.count]
        let start = DispatchTime.now().uptimeNanoseconds
        let value = try step(event)
        durations.append(DispatchTime.now().uptimeNanoseconds - start)
        checksum &+= value
    }
    return ("complete-composition-reducer", durations, warmup, checksum)
}

do {
    if CommandLine.arguments.contains("--engine") {
        var (scope, durations, warmup, checksum) = try engineReport()
        durations.sort()
        func percentile(_ fraction: Double) -> UInt64 { durations[Int((Double(durations.count - 1) * fraction).rounded(.up))] }
        let report = Report(schemaVersion: 1, scope: scope, buildConfiguration: "release",
                            os: ProcessInfo.processInfo.operatingSystemVersionString,
                            architecture: { () -> String in
                                #if arch(arm64)
                                return "arm64"
                                #else
                                return "x86_64"
                                #endif
                            }(),
                            logicalCPUCount: ProcessInfo.processInfo.processorCount, samples: durations.count,
                            warmup: warmup, medianNanoseconds: percentile(0.5), p95Nanoseconds: percentile(0.95),
                            p99Nanoseconds: percentile(0.99), maximumNanoseconds: durations.last!, checksum: checksum)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
        exit(0)
    }
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
