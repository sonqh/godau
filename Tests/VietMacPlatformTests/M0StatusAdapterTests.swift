import Testing
@testable import VietMacPlatform

struct M0StatusAdapterTests {
    @Test func mapsEveryM0ReasonPerDesignD2() {
        let table: [(PauseReason, Availability)] = [
            (.accessibility, .blocked(.accessibility)),
            (.listening, .blocked(.listening)),
            (.posting, .blocked(.posting)),
            (.unsupportedSource, .blocked(.unsupportedSource)),
            (.tapUnavailable, .blocked(.tapUnavailable)),
            (.recoveryLimit, .blocked(.recoveryLimit)),
            (.userDisabledTap, .blocked(.userDisabledTap)),
            (.transportUncertain, .blocked(.transportUncertain)),
            (.secureInput, .standby(.secureInput)),
            (.unsupportedApp, .standby(.unsupportedApp)),
            (.uncertainContext, .standby(.fieldUnreadable)),
            (.sleeping, .standby(.sleeping)),
        ]
        #expect(table.count == 12)
        for (reason, expected) in table {
            #expect(M0StatusAdapter.availability(for: .paused(reason)) == expected, "\(reason)")
        }
        #expect(M0StatusAdapter.availability(for: .active) == .active(.observed))
        #expect(M0StatusAdapter.availability(for: .disabled) == .off)
    }

    @Test func disabledHostIsEnglishModeWithCapabilitiesReported() {
        let permissions = PermissionSnapshot(accessibility: false, eventListening: true, eventPosting: false)
        let status = M0StatusAdapter.status(enabled: false, state: .disabled, permissions: permissions,
                                            inputSource: "com.apple.keylayout.ABC", frontmostBundleID: "com.apple.Notes",
                                            modeSource: .launch)
        #expect(status.mode == .english)
        #expect(status.availability == .off)
        #expect(status.capabilities == Capabilities(accessibility: false, eventListening: true, eventPosting: false))
        #expect(status.inputSourceID == "com.apple.keylayout.ABC")
        #expect(status.frontmostBundleID == "com.apple.Notes")
        #expect(status.profileID == nil && status.fieldKind == nil && status.conflictingBundleID == nil)
        #expect(!status.shortcutArmed)
    }

    @Test func enabledHostUsesPipelineState() {
        let status = M0StatusAdapter.status(enabled: true, state: .paused(.secureInput),
                                            permissions: PermissionSnapshot(accessibility: true, eventListening: true,
                                                                            eventPosting: true),
                                            inputSource: "com.apple.keylayout.US", frontmostBundleID: nil,
                                            modeSource: .menu)
        #expect(status.mode == .vietnamese)
        #expect(status.modeSource == .menu)
        #expect(status.availability == .standby(.secureInput))
    }

    @Test func equalStatusesDoNotRepublish() {
        func make(_ availability: Availability) -> RuntimeStatus {
            RuntimeStatus(mode: .vietnamese, modeSource: .menu, availability: availability, capabilities: .all,
                          inputSourceID: "com.apple.keylayout.ABC", frontmostBundleID: "com.google.Chrome",
                          profileID: nil, fieldKind: nil, conflictingBundleID: nil, shortcutArmed: false)
        }
        var publisher = StatusPublisher()
        #expect(publisher.offer(make(.active(.observed))) != nil)
        #expect(publisher.offer(make(.active(.observed))) == nil)
        #expect(publisher.offer(make(.standby(.fieldUnreadable))) != nil)
        #expect(publisher.offer(make(.standby(.fieldUnreadable))) == nil)
        #expect(publisher.offer(make(.active(.observed))) != nil)
        #expect(publisher.last == make(.active(.observed)))
    }

    @Test func excludedAppIsReportedAsExcluded() {
        let status = M0StatusAdapter.status(enabled: true, state: .paused(.unsupportedApp),
                                            permissions: PermissionSnapshot(accessibility: true, eventListening: true,
                                                                            eventPosting: true),
                                            inputSource: "com.apple.keylayout.ABC", frontmostBundleID: "com.google.Chrome",
                                            modeSource: .menu, excluded: ["com.google.Chrome"])
        #expect(status.availability == .standby(.excludedApp))
        let other = M0StatusAdapter.status(enabled: true, state: .paused(.unsupportedApp),
                                           permissions: PermissionSnapshot(accessibility: true, eventListening: true,
                                                                           eventPosting: true),
                                           inputSource: "com.apple.keylayout.ABC", frontmostBundleID: "com.slack",
                                           modeSource: .menu, excluded: ["com.google.Chrome"])
        #expect(other.availability == .standby(.unsupportedApp))
    }

    @Test func shortcutArmingFollowsTheGate() {
        let all = Capabilities.all
        #expect(!M0StatusAdapter.shortcutArmed(configured: false, capabilities: all, availability: .off, secureInput: false))
        #expect(M0StatusAdapter.shortcutArmed(configured: true, capabilities: all, availability: .off, secureInput: false))
        #expect(M0StatusAdapter.shortcutArmed(configured: true, capabilities: all,
                                              availability: .standby(.unsupportedApp), secureInput: false))
        #expect(M0StatusAdapter.shortcutArmed(configured: true, capabilities: all,
                                              availability: .blocked(.unsupportedSource), secureInput: false))
        #expect(!M0StatusAdapter.shortcutArmed(configured: true, capabilities: all, availability: .off, secureInput: true))
        #expect(!M0StatusAdapter.shortcutArmed(configured: true, capabilities: .none, availability: .off, secureInput: false))
        for reason in BlockReason.allCases where reason.needsResume {
            #expect(!M0StatusAdapter.shortcutArmed(configured: true, capabilities: all,
                                                   availability: .blocked(reason), secureInput: false))
        }
        #expect(!M0StatusAdapter.shortcutArmed(configured: true, capabilities: all,
                                               availability: .standby(.sleeping), secureInput: false))
    }
}
