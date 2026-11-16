import Testing
import VietMacPlatform
@testable import VietMacShell

func makeStatus(mode: InputMode = .vietnamese, source: ModeSource = .menu, availability: Availability,
                capabilities: Capabilities = .all, inputSourceID: String = "com.apple.keylayout.ABC",
                frontmost: String? = "com.google.Chrome", profileID: String? = nil, fieldKind: FieldKind? = nil,
                conflicting: String? = nil, shortcutArmed: Bool = false) -> RuntimeStatus {
    RuntimeStatus(mode: mode, modeSource: source, availability: availability, capabilities: capabilities,
                  inputSourceID: inputSourceID, frontmostBundleID: frontmost, profileID: profileID,
                  fieldKind: fieldKind, conflictingBundleID: conflicting, shortcutArmed: shortcutArmed)
}

private let vi = Strings(language: .vi)
private let en = Strings(language: .en)

struct StatusPresentationTests {
    @Test func activeVietnameseHasNoBadge() {
        let p = StatusPresentation(status: makeStatus(availability: .active(.observed)))
        #expect(p.uiClass == .active)
        #expect(p.title == "VI")
        #expect(p.badge == .none)
        #expect(vi(p.accessibilityLabel) == "Gõ Dấu: tiếng Việt")
        #expect(en(p.accessibilityLabel) == "Gõ Dấu: Vietnamese")
        #expect(vi(p.statusLine) == "Tiếng Việt: đang bật")
        #expect(p.detailLine == nil)
        #expect(p.nextStep == nil)
    }

    @Test func englishWithMissingGrantShowsTriangle() {
        let caps = Capabilities(accessibility: false, eventListening: true, eventPosting: true)
        let p = StatusPresentation(status: makeStatus(mode: .english, availability: .off, capabilities: caps))
        #expect(p.title == "EN")
        #expect(p.badge == .triangle)
        #expect(vi(p.accessibilityLabel) == "Gõ Dấu: tiếng Anh, có quyền chưa bật")
        #expect(en(p.accessibilityLabel) == "Gõ Dấu: English, a permission is off")
        #expect(vi(p.statusLine) == "Tiếng Anh: Gõ Dấu không đổi chữ")
    }

    @Test func englishWithAllGrantsHasNoBadgeOrDetail() {
        let p = StatusPresentation(status: makeStatus(mode: .english, availability: .off))
        #expect(p.badge == .none)
        #expect(p.detailLine == nil)
        #expect(en(p.accessibilityLabel) == "Gõ Dấu: English")
    }

    @Test func listeningIsNotRequiredWhenTheGateIsRemoved() {
        let caps = Capabilities(accessibility: true, eventListening: false, eventPosting: true)
        let features = SetupFeatures(inputMonitoringRequired: false)
        let p = StatusPresentation(status: makeStatus(mode: .english, availability: .off, capabilities: caps),
                                   features: features)
        #expect(p.badge == .none)
    }

    @Test func quietStandbyLeavesTitleUnbadged() {
        for reason in StandbyReason.allCases {
            let p = StatusPresentation(status: makeStatus(availability: .standby(reason)))
            let quiet = [.noTextField, .fieldUnreadable, .sleeping].contains(reason)
            #expect(p.title == "VI")
            #expect(p.badge == (quiet ? .none : .pause), "\(reason)")
            #expect(p.uiClass == (quiet ? .standbyQuiet : .standbyShown))
            #expect(vi(p.accessibilityLabel) == (quiet ? "Gõ Dấu: tiếng Việt" : "Gõ Dấu: tiếng Việt, tạm dừng ở đây"))
            #expect(vi(p.statusLine) == "Tiếng Việt: tạm dừng ở đây")
        }
    }

    @Test func blockedReasonsShowTriangleAndOneAction() {
        for reason in BlockReason.allCases {
            let p = StatusPresentation(status: makeStatus(availability: .blocked(reason), conflicting: "com.tuyenmai.openkey"))
            #expect(p.badge == .triangle)
            #expect(vi(p.accessibilityLabel) == "Gõ Dấu: tiếng Việt, cần xử lý")
            #expect(en(p.statusLine) == "Vietnamese: Needs Attention")
            #expect(p.detailLine != nil)
            #expect(p.nextStep != nil, "\(reason)")
        }
    }

    /// Detail line and action for every reason (ux-spec 5.4), in both languages.
    @Test func reasonTableMatchesSpec() {
        typealias Row = (Availability, String, String, String?, String?, ShellAction?)
        let rows: [Row] = [
            (.blocked(.accessibility), "Quyền Trợ năng chưa bật.", "The Accessibility permission is off.",
             "Bật quyền Trợ năng…", "Turn On Accessibility…", .openSetup(.accessibility)),
            (.blocked(.listening), "Quyền Theo dõi đầu vào chưa bật.", "The Input Monitoring permission is off.",
             "Bật quyền Theo dõi đầu vào…", "Turn On Input Monitoring…", .openSetup(.inputMonitoring)),
            (.blocked(.posting), "Gõ Dấu chưa gửi phím được.", "Gõ Dấu cannot send keys yet.",
             "Mở lại Gõ Dấu", "Reopen Gõ Dấu", .relaunch),
            (.blocked(.unsupportedSource), "Bàn phím đang là Telex. Hãy chọn ABC.", "The keyboard is Telex. Select ABC.",
             "Mở cài đặt Bàn phím…", "Open Keyboard Settings…", .openKeyboardSettings),
            (.blocked(.conflictingTool), "openkey cũng đang đổi chữ bạn gõ.", "openkey also changes what you type.",
             "Cách thoát openkey…", "How to Quit openkey…", .openHelp(.otherTool)),
            (.blocked(.tapUnavailable), "Gõ Dấu chưa nhận được phím.", "Gõ Dấu cannot receive keys.",
             "Thử lại", "Try Again", .resume),
            (.blocked(.userDisabledTap), "macOS đã tạm dừng việc nhận phím của Gõ Dấu.",
             "macOS stopped the key input of Gõ Dấu.", "Tiếp tục gõ tiếng Việt", "Resume Vietnamese", .resume),
            (.blocked(.recoveryLimit), "Gõ Dấu tạm dừng vì máy phản hồi chậm nhiều lần.",
             "Gõ Dấu paused because the Mac responded slowly several times.",
             "Tiếp tục gõ tiếng Việt", "Resume Vietnamese", .resume),
            (.blocked(.transportUncertain), "Gõ Dấu tạm dừng để giữ an toàn cho chữ. Hãy xem lại từ bạn vừa gõ.",
             "Gõ Dấu paused to keep your text safe. Check the last word you typed.",
             "Tiếp tục gõ tiếng Việt", "Resume Vietnamese", .resume),
            (.standby(.secureInput), "Một ô mật khẩu hoặc chế độ nhập an toàn đang bật. Tiếng Việt tạm dừng.",
             "A password field or secure input is on. Vietnamese is paused.",
             "Xem lý do…", "See the Reason…", .openHelp(.password)),
            (.standby(.passwordField), "Đây là ô mật khẩu. Gõ Dấu không đổi chữ ở đây.",
             "This is a password field. Gõ Dấu does not change text here.", nil, nil, nil),
            (.standby(.unsupportedApp), "Gõ Dấu chưa hỗ trợ Chrome. Chữ bạn gõ được giữ nguyên.",
             "Gõ Dấu does not support Chrome yet. Your text stays as typed.",
             "Xem ứng dụng được hỗ trợ…", "See Supported Apps…", .openSettings(.apps)),
            (.standby(.excludedApp), "Bạn đã tắt tiếng Việt trong Chrome.", "You turned off Vietnamese in Chrome.",
             "Bật lại tiếng Việt trong Chrome", "Turn On Vietnamese in Chrome",
             .removeExclusion(bundleID: "com.google.Chrome")),
            (.standby(.unsupportedField), "Gõ Dấu chưa hỗ trợ Thanh địa chỉ trong Chrome.",
             "Gõ Dấu does not support Address bar in Chrome yet.",
             "Xem ứng dụng được hỗ trợ…", "See Supported Apps…", .openSettings(.apps)),
            (.standby(.noTextField), "Chưa chọn ô để gõ.", "No text field is selected.", nil, nil, nil),
            (.standby(.fieldUnreadable), "Gõ Dấu không kiểm tra được ô này. Chữ bạn gõ được giữ nguyên.",
             "Gõ Dấu cannot check this field. Your text stays as typed.", nil, nil, nil),
            (.standby(.sleeping), "Máy vừa ngủ. Gõ Dấu sẽ tự chạy lại.",
             "The Mac was asleep. Gõ Dấu starts again automatically.", nil, nil, nil),
        ]
        for (availability, detailVI, detailEN, actionVI, actionEN, action) in rows {
            let status = makeStatus(availability: availability, inputSourceID: "com.apple.inputmethod.VietnameseIM.Telex",
                                    fieldKind: .addressBar, conflicting: "com.tuyenmai.openkey")
            let p = StatusPresentation(status: status)
            #expect(p.detailLine.map { vi($0) } == detailVI, "\(availability)")
            #expect(p.detailLine.map { en($0) } == detailEN, "\(availability)")
            #expect(p.nextStep.map { vi($0.title) } == actionVI, "\(availability)")
            #expect(p.nextStep.map { en($0.title) } == actionEN, "\(availability)")
            #expect(p.nextStep?.action == action, "\(availability)")
        }
    }

    @Test func tapRetryFailureOffersReopen() {
        let p = StatusPresentation(status: makeStatus(availability: .blocked(.tapUnavailable)),
                                   context: PresentationContext(tapRetryFailed: true))
        #expect(p.nextStep == NextStep(title: LocalizedText("action.reopen"), action: .relaunch))
        #expect(en(p.nextStep!.title) == "Reopen Gõ Dấu")
    }

    @Test func noSurfaceSaysOnUnlessActive() {
        var statuses: [RuntimeStatus] = [makeStatus(mode: .english, availability: .off)]
        statuses += BlockReason.allCases.map { makeStatus(availability: .blocked($0)) }
        statuses += StandbyReason.allCases.map { makeStatus(availability: .standby($0)) }
        for status in statuses {
            let p = StatusPresentation(status: status)
            #expect(vi(p.statusLine) != "Tiếng Việt: đang bật")
            #expect(en(p.statusLine) != "Vietnamese: On")
        }
    }

    @Test func renderedTextHasNoRawKeysOrFaultWords() {
        var statuses: [RuntimeStatus] = [makeStatus(availability: .active(.observed)),
                                         makeStatus(availability: .active(.eventOnly)),
                                         makeStatus(mode: .english, availability: .off, capabilities: .none)]
        statuses += BlockReason.allCases.map { makeStatus(availability: .blocked($0), conflicting: "x.y.Tool") }
        statuses += StandbyReason.allCases.map { makeStatus(availability: .standby($0), fieldKind: .webText) }
        for status in statuses {
            let p = StatusPresentation(status: status)
            for strings in [vi, en] {
                var lines = [strings(p.accessibilityLabel), strings(p.statusLine)]
                if let detail = p.detailLine { lines.append(strings(detail)) }
                if let step = p.nextStep { lines.append(strings(step.title)) }
                let enumNames = BlockReason.allCases.map(\.rawValue) + StandbyReason.allCases.map(\.rawValue)
                for line in lines {
                    let lower = line.lowercased()
                    #expect(StringTable.bundled.entries[line] == nil && !line.contains("@key:"), "\(line)")
                    #expect(!["error", "failed", "lỗi", "thất bại"].contains { lower.contains($0) }, "\(line)")
                    #expect(!enumNames.contains { line.contains($0) }, "\(line)")
                }
            }
        }
    }

    @Test func presentationIsPureFunctionOfStatus() {
        let status = makeStatus(availability: .standby(.unsupportedApp))
        #expect(StatusPresentation(status: status) == StatusPresentation(status: status))
    }
}
