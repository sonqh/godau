import Testing
import VietMacPlatform
@testable import VietMacShell

private let vi = Strings(language: .vi)
private let en = Strings(language: .en)

struct SetupScreenTests {
    private func english(_ caps: Capabilities, source: String = "com.apple.keylayout.ABC") -> RuntimeStatus {
        makeStatus(mode: .english, availability: .off, capabilities: caps, inputSourceID: source)
    }

    private func screen(_ step: SetupStep, _ status: RuntimeStatus,
                        _ context: SetupContext = SetupContext()) -> SetupScreen {
        SetupScreen(step: step, plan: SetupPlan(status: status), status: status, context: context)
    }

    @Test func welcomeMatchesSpecAndMockup() {
        let s = screen(.welcome, english(.none))
        #expect(vi(s.indicator) == "Bước 1 / 6")
        #expect(vi(s.heading) == "Gõ tiếng Việt kiểu Telex, không gạch chân")
        #expect(s.paragraphs.last == LocalizedText("setup.welcome.otherTool"))
        #expect(s.primary == SetupButton(LocalizedText("setup.welcome.start"), .start))
        #expect(s.back == nil && s.link == nil)
    }

    /// Mockup "Setup: Input Monitoring": step 2 of 6, three instructions, Off row, help, Back, Later, primary.
    @Test func missingGrantStep() {
        let s = screen(.inputMonitoring, english(.none))
        #expect(vi(s.indicator) == "Bước 2 / 6")
        #expect(vi(s.heading) == "Cho phép Gõ Dấu nhận phím bạn gõ")
        #expect(s.instructions.count == 3)
        #expect(s.statusRow.map { vi($0.value) } == "Chưa bật")
        #expect(s.statusRow?.satisfied == false)
        #expect(s.disclosure != nil)
        #expect(s.primary == SetupButton(LocalizedText("setup.openSystemSettings"), .requestPermission(.inputMonitoring)))
        #expect(s.back != nil)
        #expect(s.link.map { vi($0.title) } == "Để sau")
        #expect(s.secondary == nil)
    }

    @Test func grantedStepShowsOnAndContinueWithoutStaleHelp() {
        let caps = Capabilities(accessibility: false, eventListening: true, eventPosting: false)
        let s = screen(.inputMonitoring, english(caps))
        #expect(s.statusRow.map { en($0.value) } == "On ✓")
        #expect(s.primary.command == .next)
        #expect(s.disclosure == nil)
    }

    @Test func reopenOfferAfterTwentySeconds() {
        let s = screen(.accessibility, english(.none), SetupContext(reopenOffered: true))
        #expect(s.secondary == SetupButton(LocalizedText("action.reopen"), .reopen))
        #expect(SetupContext.reopenDelay == 20)
    }

    @Test func postingStuckOffersRelaunchRow() {
        let caps = Capabilities(accessibility: true, eventListening: true, eventPosting: false)
        let s = screen(.accessibility, english(caps))
        #expect(s.extraRow.map { vi($0.text) } == "Mở lại Gõ Dấu để dùng quyền bạn vừa bật.")
        #expect(s.extraRow?.button.command == .reopen)
        #expect(s.statusRow?.satisfied == false)
    }

    @Test func updateHeadingOnlyWhileMissing() {
        let s = screen(.accessibility, english(.none), SetupContext(updateHeading: true))
        #expect(vi(s.heading) == "Hãy bật lại quyền cho Gõ Dấu")
        let granted = screen(.accessibility, english(.all), SetupContext(updateHeading: true))
        #expect(vi(granted.heading) == "Cho phép Gõ Dấu đổi chữ trong ô bạn đang gõ")
    }

    @Test func keyboardStepNamesWrongSourceAndNeverSwitches() {
        let s = screen(.keyboard, english(.all, source: "com.apple.inputmethod.VietnameseIM.Telex"))
        #expect(vi(s.paragraphs[0]) == "Gõ Dấu cần bàn phím ABC hoặc U.S. Bàn phím đang chọn: **Telex**.")
        #expect(s.statusRow.map { vi($0.value) } == "Telex ✗")
        #expect(s.instructions == [LocalizedText("setup.keyboard.wrongSource")])
        #expect(s.primary.command == .openKeyboardSettings)
        let missingABC = screen(.keyboard, english(.all, source: "x.Telex"), SetupContext(supportedSourceEnabled: false))
        #expect(missingABC.instructions == [LocalizedText("setup.keyboard.addABC")])
        let ok = screen(.keyboard, english(.all))
        #expect(ok.statusRow.map { vi($0.value) } == "ABC ✓")
        #expect(ok.primary.command == .next)
    }

    @Test func tryItNotesVariant() {
        let s = screen(.tryIt, english(.all))
        #expect(vi(s.indicator) == "Bước 5 / 6")
        #expect(s.showsModeSwitch)
        #expect(s.contentButtons.map(\.command) == [.openNotes, .textChanged, .textNotChanged])
        #expect(vi(s.paragraphs[0]) == "Kết quả đúng: **tiếng Việt**")
        #expect(s.link.map { vi($0.title) } == "Bỏ qua")
        #expect(s.notes.contains(LocalizedText("setup.try.telex")))
        // The copy names the result and never promises that VietMac will change the text.
        for text in s.paragraphs + s.instructions + s.notes {
            #expect(!vi(text).contains("sẽ đổi") && !en(text).contains("will change"))
        }
    }

    @Test func textDidNotChangeShowsCurrentReason() {
        let status = makeStatus(availability: .blocked(.unsupportedSource),
                                inputSourceID: "com.apple.inputmethod.VietnameseIM.Telex")
        let s = SetupScreen(step: .tryIt, plan: SetupPlan(status: status), status: status,
                            context: SetupContext(tryItAnswer: .notChanged))
        #expect(s.tryItProblem.map { vi($0.statusLine) } == "Tiếng Việt: cần xử lý")
        #expect(s.tryItProblem?.detail.map { vi($0) } == "Bàn phím đang là Telex. Hãy chọn ABC.")
        #expect(s.tryItProblem?.step.map { vi($0.title) } == "Mở cài đặt Bàn phím…")
    }

    @Test func readyStepFinishesWithDone() {
        let s = screen(.ready, english(.all))
        #expect(vi(s.indicator) == "Bước 6 / 6")
        #expect(s.primary == SetupButton(LocalizedText("setup.ready.done"), .done))
        #expect(s.link == nil)
    }

    @Test func everyStepRendersInBothLanguages() {
        let status = english(.none, source: "x.Telex")
        let features = SetupFeatures(conflictDetection: true)
        let conflict = makeStatus(mode: .english, availability: .off, capabilities: .none, conflicting: "x.Tool")
        for step in SetupStep.allCases {
            let s = step == .otherTool
                ? SetupScreen(step: step, plan: SetupPlan(status: conflict, features: features), status: conflict)
                : SetupScreen(step: step, plan: SetupPlan(status: status), status: status)
            var texts = [s.indicator, s.heading, s.primary.title] + s.paragraphs + s.instructions + s.notes
            if let row = s.statusRow { texts.append(row.value) }
            for strings in [vi, en] {
                for text in texts {
                    #expect(StringTable.bundled.entries[strings(text)] == nil, "\(step) \(text.key)")
                }
            }
        }
    }
}

struct LaunchDecisionTests {
    private func decide(_ status: RuntimeStatus, completedOnce: Bool, lastSeen: SetupStep?,
                        login: Bool = false, features: SetupFeatures = SetupFeatures()) -> LaunchDecision {
        LaunchDecision.decide(status: status, plan: SetupPlan(status: status, features: features),
                              completedOnce: completedOnce, lastSeen: lastSeen, loginLaunch: login)
    }

    private let missingAX = makeStatus(mode: .english, availability: .off,
                                       capabilities: Capabilities(accessibility: false, eventListening: true,
                                                                  eventPosting: false))

    @Test func firstLaunchOpensWelcome() {
        let d = decide(makeStatus(mode: .english, availability: .off, capabilities: .none),
                       completedOnce: false, lastSeen: nil)
        #expect(d == LaunchDecision(step: .welcome, activates: true, updateHeading: false))
    }

    @Test func relaunchDuringSetupOpensFirstMissingItem() {
        let d = decide(missingAX, completedOnce: false, lastSeen: .inputMonitoring)
        #expect(d == LaunchDecision(step: .accessibility, activates: true, updateHeading: false))
    }

    @Test func completeSetupOpensNothing() {
        #expect(decide(makeStatus(mode: .english, availability: .off), completedOnce: true, lastSeen: .ready) == .none)
    }

    @Test func fallbackBeforeU15ShowsWithoutActivating() {
        let d = decide(missingAX, completedOnce: true, lastSeen: .ready, login: true)
        #expect(d == LaunchDecision(step: .accessibility, activates: false, updateHeading: true))
    }

    @Test func afterU15LoginLaunchOpensNothing() {
        let features = SetupFeatures(distinguishesLoginLaunch: true)
        #expect(decide(missingAX, completedOnce: true, lastSeen: .ready, login: true, features: features) == .none)
        let manual = decide(missingAX, completedOnce: true, lastSeen: .ready, login: false, features: features)
        #expect(manual == LaunchDecision(step: .accessibility, activates: true, updateHeading: true))
    }
}
