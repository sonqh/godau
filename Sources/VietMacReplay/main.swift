import Foundation
import VietMacCore

/// Planner fixture: one previous/next pair and the expected plan.
struct PlanFixture: Decodable {
    let id: String
    let previous: String
    let next: String
    let deleteCount: Int
    let insertion: String
}

/// Semantic composition fixture. `events` is a string: a letter is a key, ` ` is a boundary, `<` is Backspace,
/// `!` is an invalidation. `steps` lists the visible text after every event (committed text plus the word).
struct CompositionFixture: Decodable {
    let id: String
    let events: String
    let steps: [String]?
    let text: String
}

/// Replays a composition fixture against an independent text buffer. Each event records its action:
/// `pass` (the key reaches the field), `replace` (planned deletion and insertion), or `none`.
func replay(_ fixture: CompositionFixture) throws -> (text: String, steps: [String], actions: [String]) {
    var composer = TelexComposer()
    var buffer = ""
    var steps: [String] = []
    var actions: [String] = []
    for scalar in fixture.events.unicodeScalars {
        switch scalar {
        case " ":
            composer.reset()
            buffer += " "
            actions.append("pass")
        case "<":
            buffer = String(buffer.dropLast())
            let expected = String(composer.text.dropLast())
            var next = composer
            next.backspace()
            if next.text == expected { composer = next } else { composer.reset() }
            actions.append("pass")
        case "!":
            composer.reset()
            actions.append("none")
        default:
            let before = composer.text
            switch composer.input(UInt8(scalar.value)) {
            case .untracked:
                composer.reset()
                buffer.unicodeScalars.append(scalar)
                actions.append("pass")
            case .text(let after):
                if after == before + String(scalar) {
                    buffer.unicodeScalars.append(scalar)
                    actions.append("pass")
                } else {
                    let plan = try ReplacementPlan.compute(previous: before, next: after)
                    buffer = String(buffer.dropLast(plan.deleteCount)) + plan.insertion
                    actions.append("replace -\(plan.deleteCount) +\(plan.insertion)")
                }
            }
        }
        steps.append(buffer)
    }
    return (buffer, steps, actions)
}

do {
    let path = CommandLine.arguments.dropFirst().first ?? "Fixtures/replacement-plans.json"
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    var failures = 0
    var count = 0
    if let fixtures = try? JSONDecoder().decode([PlanFixture].self, from: data), !fixtures.isEmpty {
        for fixture in fixtures {
            let plan = try ReplacementPlan.compute(previous: fixture.previous, next: fixture.next)
            let model = String(fixture.previous.dropLast(plan.deleteCount)) + plan.insertion
            let passed = model == fixture.next && plan.deleteCount == fixture.deleteCount && plan.insertion == fixture.insertion
            print("\(passed ? "PASS" : "FAIL") \(fixture.id)")
            failures += passed ? 0 : 1
        }
        count = fixtures.count
        print("scope=replacement-planner-only passed=\(count - failures) failed=\(failures)")
    } else {
        let fixtures = try JSONDecoder().decode([CompositionFixture].self, from: data)
        guard !fixtures.isEmpty else { throw NSError(domain: "VietMacReplay", code: 1) }
        let verbose = CommandLine.arguments.contains("--verbose")
        for fixture in fixtures {
            let result = try replay(fixture)
            let nfc = result.text.unicodeScalars.elementsEqual(result.text.precomposedStringWithCanonicalMapping.unicodeScalars)
            let passed = result.text == fixture.text && (fixture.steps.map { $0 == result.steps } ?? true) && nfc
            print("\(passed ? "PASS" : "FAIL") \(fixture.id)\(passed ? "" : " got \(result.text) steps \(result.steps)")")
            if verbose {
                for (event, action) in zip(fixture.events.unicodeScalars, result.actions) { print("  \(event) \(action)") }
            }
            failures += passed ? 0 : 1
        }
        count = fixtures.count
        print("scope=semantic-composition passed=\(count - failures) failed=\(failures)")
    }
    if failures > 0 { exit(1) }
} catch {
    FileHandle.standardError.write(Data("Replay failed: \(error)\n".utf8))
    exit(1)
}
