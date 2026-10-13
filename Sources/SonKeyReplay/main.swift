import Foundation
import SonKeyCore

struct Fixture: Decodable {
    let id: String
    let previous: String
    let next: String
    let deleteCount: Int
    let insertion: String
}

do {
    let path = CommandLine.arguments.dropFirst().first ?? "Fixtures/replacement-plans.json"
    let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    guard !fixtures.isEmpty else { throw NSError(domain: "SonKeyReplay", code: 1) }
    var failures = 0
    for fixture in fixtures {
        let plan = try ReplacementPlan.compute(previous: fixture.previous, next: fixture.next)
        let model = String(fixture.previous.dropLast(plan.deleteCount)) + plan.insertion
        let passed = model == fixture.next && plan.deleteCount == fixture.deleteCount && plan.insertion == fixture.insertion
        print("\(passed ? "PASS" : "FAIL") \(fixture.id)")
        failures += passed ? 0 : 1
    }
    print("scope=replacement-planner-only passed=\(fixtures.count - failures) failed=\(failures)")
    if failures > 0 { exit(1) }
} catch {
    FileHandle.standardError.write(Data("Replay failed: \(error)\n".utf8))
    exit(1)
}
