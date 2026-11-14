import Testing
import VietMacPlatform
@testable import VietMacShell

struct SetupPlanTests {
    private func status(_ caps: Capabilities, source: String = "com.apple.keylayout.ABC",
                        conflicting: String? = nil) -> RuntimeStatus {
        makeStatus(mode: .english, availability: .off, capabilities: caps, inputSourceID: source,
                   conflicting: conflicting)
    }

    @Test func defaultBuildHasSixSteps() {
        let plan = SetupPlan(status: status(.none))
        #expect(plan.steps == [.welcome, .inputMonitoring, .accessibility, .keyboard, .tryIt, .ready])
        #expect(plan.indicator(for: .accessibility)! == (3, 6))
    }

    @Test func noInputMonitoringStepWhenNotRequired() {
        let plan = SetupPlan(status: status(.none), features: SetupFeatures(inputMonitoringRequired: false))
        #expect(!plan.steps.contains(.inputMonitoring))
        #expect(plan.indicator(for: .ready)!.count == 5)
    }

    @Test func otherToolStepNeedsDetectionAndAConflict() {
        let conflict = status(.all, conflicting: "com.tuyenmai.openkey")
        #expect(!SetupPlan(status: conflict).steps.contains(.otherTool))
        #expect(SetupPlan(status: conflict).showsOtherToolLine)
        let detecting = SetupFeatures(conflictDetection: true)
        #expect(SetupPlan(status: conflict, features: detecting).steps.contains(.otherTool))
        #expect(!SetupPlan(status: status(.all), features: detecting).steps.contains(.otherTool))
        #expect(!SetupPlan(status: conflict, features: detecting).showsOtherToolLine)
    }

    @Test func firstLaunchStartsAtWelcome() {
        let s = status(.none)
        let plan = SetupPlan(status: s)
        #expect(!plan.isComplete(status: s))
        #expect(plan.startStep(status: s, lastSeen: nil) == .welcome)
    }

    @Test func relaunchStartsAtFirstMissingItem() {
        let s = status(Capabilities(accessibility: false, eventListening: true, eventPosting: false))
        #expect(SetupPlan(status: s).startStep(status: s, lastSeen: .inputMonitoring) == .accessibility)
    }

    @Test func gateOrderIsCapabilitiesThenSourceThenConflict() {
        let features = SetupFeatures(conflictDetection: true)
        let wrongSource = status(.all, source: "com.apple.inputmethod.VietnameseIM.Telex", conflicting: "x.tool")
        #expect(SetupPlan(status: wrongSource, features: features).firstMissing(status: wrongSource) == .keyboard)
        let conflictOnly = status(.all, conflicting: "x.tool")
        #expect(SetupPlan(status: conflictOnly, features: features).firstMissing(status: conflictOnly) == .otherTool)
        let missingListen = status(Capabilities(accessibility: false, eventListening: false, eventPosting: false))
        #expect(SetupPlan(status: missingListen).firstMissing(status: missingListen) == .inputMonitoring)
    }

    @Test func completionReadsStatusFieldsOnly() {
        let ready = status(.all)
        #expect(SetupPlan(status: ready).isComplete(status: ready))
        // Availability does not matter: a blocked runtime with every field ready is still set up.
        let blocked = makeStatus(availability: .blocked(.recoveryLimit))
        #expect(SetupPlan(status: blocked).isComplete(status: blocked))
        let conflict = status(.all, conflicting: "x.tool")
        #expect(!SetupPlan(status: conflict).isComplete(status: conflict))
        let noPosting = status(Capabilities(accessibility: true, eventListening: true, eventPosting: false))
        #expect(!SetupPlan(status: noPosting).isComplete(status: noPosting))
        #expect(!SetupPlan(status: noPosting).isSatisfied(.accessibility, status: noPosting))
    }

    @Test func listeningIsOptionalWhenTheGateIsRemoved() {
        let features = SetupFeatures(inputMonitoringRequired: false)
        let s = status(Capabilities(accessibility: true, eventListening: false, eventPosting: true))
        #expect(SetupPlan(status: s, features: features).isComplete(status: s))
    }

    @Test func reopenWithNothingMissingResumesAtTryIt() {
        let s = status(.all)
        let plan = SetupPlan(status: s)
        #expect(plan.startStep(status: s, lastSeen: .keyboard) == .tryIt)
        #expect(plan.startStep(status: s, lastSeen: .ready) == .ready)
    }

    @Test func userStepsAreNeverSatisfiedByStatus() {
        let s = status(.all)
        let plan = SetupPlan(status: s)
        for step in [SetupStep.welcome, .tryIt, .ready] { #expect(!plan.isSatisfied(step, status: s)) }
        #expect(plan.next(after: .keyboard) == .tryIt)
        #expect(plan.previous(before: .welcome) == nil)
    }
}
