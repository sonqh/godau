import CoreGraphics
import Testing
import VietMacCore
@testable import VietMacPlatform

private func payload(_ event: CGEvent) -> String {
    var units = [UniChar](repeating: 0, count: 128)
    var count = 0
    units.withUnsafeMutableBufferPointer {
        event.keyboardGetUnicodeString(maxStringLength: $0.count, actualStringLength: &count,
                                       unicodeString: $0.baseAddress!)
    }
    return String(decoding: units.prefix(min(count, units.count)), as: UTF16.self)
}

struct PreparedTransportTests {
    @Test func preparesEveryEventBeforeTheFirstPost() throws {
        var created = 0
        let transport = PreparedTransport(marker: 1234, factory: { code, down in
            created += 1
            return CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
        })
        let plan = try ReplacementPlan.compute(previous: "tieng", next: "tiêng")
        let prepared = try transport.prepare(plan)
        #expect(created == 8)
        var posted: [CGEvent] = []
        let result = transport.send(prepared, isCurrent: { true }, post: {
            #expect(created == 8)
            posted.append($0)
            return true
        })
        #expect(result == .posted)
        #expect(posted.map(\.type) == [.keyDown, .keyUp, .keyDown, .keyUp, .keyDown, .keyUp, .keyDown, .keyUp])
        #expect(posted.prefix(6).allSatisfy { $0.getIntegerValueField(.keyboardEventKeycode) == 51 })
        #expect(payload(posted[6]) == "êng")
        #expect(payload(posted[7]) == "êng")
        #expect(posted.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == 1234 && $0.flags.isEmpty })
    }

    @Test func failureAfterPreparingDeletionStillPostsNothing() throws {
        for failureAt in 1...4 {
            var created = 0
            let transport = PreparedTransport(marker: 7, factory: { code, down in
                created += 1
                return created == failureAt ? nil : CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)
            })
            let plan = try ReplacementPlan.compute(previous: "a", next: "á")
            #expect(throws: TransportError.preparationFailed) { try transport.prepare(plan) }
            #expect(created == failureAt)
        }
    }

    @Test func staleGenerationPostsNothingAndCannotCommit() throws {
        let transport = PreparedTransport(marker: 9)
        let prepared = try transport.prepare(ReplacementPlan.compute(previous: "a", next: "á"))
        var posts = 0
        #expect(transport.send(prepared, isCurrent: { false }, post: { _ in posts += 1; return true }) == .staleBeforeSend)
        #expect(posts == 0)
    }

    @Test func partialSendStopsWithoutRollbackAndConsumesItsTrigger() throws {
        let transport = PreparedTransport(marker: 9)
        let prepared = try transport.prepare(ReplacementPlan.compute(previous: "a", next: "á"))
        var posts = 0
        let result = transport.send(prepared, isCurrent: { posts < 1 }, post: { _ in posts += 1; return true })
        #expect(result == .uncertainAfterSend)
        #expect(posts == 1) // No remaining insertion and no repair/rollback events.
        var model = PrototypePipeline(environment: InputEnvironment(permissions: .init(
            accessibility: true, eventListening: true, eventPosting: true)))
        model.setEnabled(true)
        model.consumeAfterUncertainSend(1)
        #expect(model.state == .paused(.transportUncertain))
        #expect(model.handle(.keyUp(1)) == .consume)
    }

    @Test func maximumPayloadIsPreparedWithoutUTF16DeletionConfusion() throws {
        let transport = PreparedTransport(marker: 10)
        let prepared = try transport.prepare(ReplacementPlan.compute(previous: "a", next: String(repeating: "ế", count: 64)))
        #expect(prepared.events.count == 4)
        #expect(payload(prepared.events[2]) == String(repeating: "ế", count: 64))
    }
}
