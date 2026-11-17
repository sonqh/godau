import Testing
import VietMacPlatform
@testable import VietMacShell

struct MenuModelTests {
    private func model(_ status: RuntimeStatus, setupComplete: Bool = true, shortcut: String? = nil,
                       excluded: Set<String> = [], exclusions: Bool = true) -> MenuModel {
        MenuModel(status: status, presentation: StatusPresentation(status: status), setupComplete: setupComplete,
                  shortcutDisplay: shortcut, excluded: excluded, exclusionsSupported: exclusions)
    }

    private func commands(_ model: MenuModel) -> [MenuModel.Command] {
        model.items.compactMap { if case .command(let c, _) = $0 { c } else { nil } }
    }

    private func exclusion(_ model: MenuModel) -> MenuModel.Item? {
        model.items.first { if case .exclusion = $0 { true } else { false } }
    }

    @Test func activeMenuOrder() {
        let m = model(makeStatus(availability: .active(.observed), frontmost: "com.apple.Safari"))
        let vi = Strings(language: .vi)
        guard case .info(let line, secondary: false) = m.items[0] else { Issue.record("no status line"); return }
        #expect(vi(line) == "Tiếng Việt: đang bật")
        #expect(m.items[1] == .separator)
        #expect(m.items[2] == .mode(.vietnamese, checked: true, chord: nil))
        #expect(m.items[3] == .mode(.english, checked: false, chord: nil))
        guard case .exclusion(_, let title, false)? = exclusion(m) else { Issue.record("no exclusion"); return }
        #expect(vi(title) == "Tắt tiếng Việt trong Safari")
        #expect(commands(m) == [.help, .saveReport, .settings, .quit])
    }

    @Test func notActiveShowsDetailAndOneAction() {
        let m = model(makeStatus(availability: .blocked(.transportUncertain)))
        let steps = m.items.filter { if case .nextStep = $0 { true } else { false } }
        #expect(steps.count == 1)
        guard case .info(_, secondary: true) = m.items[1] else { Issue.record("no detail line"); return }
    }

    @Test func exclusionIsOfferedForAnAppOutsideTheRequiredFive() {
        let slack = "com.tinyspeck.slackmacgap"
        let m = model(makeStatus(availability: .active(.eventOnly), frontmost: slack))
        #expect(exclusion(m) != nil)
        #expect(!commands(m).contains(.continueSetup))
        guard case .exclusion(let bundleID, _, let excluded)? = exclusion(m) else { return }
        #expect(bundleID == slack)
        #expect(!excluded)
    }

    @Test func continueSetupWhileIncomplete() {
        let m = model(makeStatus(mode: .english, availability: .off, capabilities: .none), setupComplete: false)
        #expect(commands(m).first == .continueSetup)
    }

    @Test func excludedAppReadsTurnOnOnce() {
        let s = makeStatus(availability: .standby(.excludedApp), frontmost: "com.google.Chrome")
        let m = model(s, excluded: ["com.google.Chrome"])
        #expect(exclusion(m) == nil)
        let steps = m.items.compactMap { if case .nextStep(let s) = $0 { s } else { nil } }
        #expect(steps == [NextStep(title: LocalizedText("menu.turnOnInApp", "Chrome"),
                                   action: .removeExclusion(bundleID: "com.google.Chrome"))])
    }

    @Test func noExclusionItemWhenHostCannotApplyIt() {
        let m = model(makeStatus(availability: .active(.observed)), exclusions: false)
        #expect(exclusion(m) == nil)
    }

    @Test func chordOnlyWhileArmed() {
        let unarmed = model(makeStatus(availability: .standby(.secureInput), shortcutArmed: false), shortcut: "⌃⌥V")
        #expect(unarmed.items.contains(.mode(.vietnamese, checked: true, chord: nil)))
        let armed = model(makeStatus(availability: .active(.observed), shortcutArmed: true), shortcut: "⌃⌥V")
        #expect(armed.items.contains(.mode(.vietnamese, checked: true, chord: "⌃⌥V")))
    }

    @Test func saveReportIsAnOptionAlternate() {
        let m = model(makeStatus(availability: .active(.observed)))
        #expect(m.items.contains(.command(.saveReport, alternate: true)))
    }

    @Test func quickPassThroughExcludedAppDoesNotFlicker() {
        let active = StatusPresentation(status: makeStatus(availability: .active(.observed)))
        let paused = StatusPresentation(status: makeStatus(availability: .standby(.excludedApp)))
        let quiet = StatusPresentation(status: makeStatus(availability: .standby(.noTextField)))
        #expect(TitleTiming.timing(from: active, to: paused) == .delayed(milliseconds: 500))
        #expect(TitleTiming.timing(from: paused, to: active) == .immediate)
        #expect(TitleTiming.timing(from: active, to: quiet) == .immediate)
    }

    @Test func blockedAndModeChangesApplyAtOnce() {
        let active = StatusPresentation(status: makeStatus(availability: .active(.observed)))
        let blocked = StatusPresentation(status: makeStatus(availability: .blocked(.accessibility)))
        let english = StatusPresentation(status: makeStatus(mode: .english, availability: .off))
        let pausedFromEnglish = StatusPresentation(status: makeStatus(availability: .standby(.secureInput)))
        #expect(TitleTiming.timing(from: active, to: blocked) == .immediate)
        #expect(TitleTiming.timing(from: active, to: english) == .immediate)
        #expect(TitleTiming.timing(from: english, to: pausedFromEnglish) == .immediate)
        #expect(TitleTiming.timing(from: nil, to: blocked) == .immediate)
    }

    @Test func stubCatalogLabelsOnlyFieldsWithNativeEvidence() {
        #expect(ProfileCatalog.stub.profiles.count == 10)
        #expect(ProfileCatalog.stub.profiles.filter { !$0.tested }.map(\.id) == ["vscode.find", "notes.text"])
        #expect(ProfileCatalog.stub.bundleIDs.count == 5)
    }
}
