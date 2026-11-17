import Testing
import VietMacPlatform
@testable import VietMacShell

private let vi = Strings(language: .vi)
private let en = Strings(language: .en)

struct ShortcutChordTests {
    @Test func rejectsPlainLetterAndModifierOnly() {
        let plain = ShortcutChord.validate(keyCode: 9, modifiers: [], keyLabel: "V", modifierOnly: false, systemShortcuts: [])
        #expect(plain == .failure(.needsModifier))
        #expect(vi(ShortcutChord.Rejection.needsModifier.message) == "Thêm ⌘, ⌃ hoặc ⌥, và một phím khác. Hoặc chỉ dùng ⌃⇧.")
        let shiftOnly = ShortcutChord.validate(keyCode: 9, modifiers: [.shift], keyLabel: "V", modifierOnly: false,
                                               systemShortcuts: [])
        #expect(shiftOnly == .failure(.needsModifier))
        let gesture = ShortcutChord.validate(keyCode: 58, modifiers: [.option], keyLabel: "", modifierOnly: true,
                                             systemShortcuts: [])
        #expect(gesture == .failure(.needsModifier))
    }

    @Test func acceptsControlShiftAloneOnly() {
        let gesture = ShortcutChord.validate(keyCode: ShortcutChord.modifierOnlyKeyCode, modifiers: [.control, .shift],
                                             keyLabel: "", modifierOnly: true, systemShortcuts: [])
        #expect(gesture == .success(.controlShift))
        #expect(ShortcutChord.controlShift.isModifierOnly)
        #expect(ShortcutChord.controlShift.display == "⌃⇧")
        for other: ShortcutChord.Modifiers in [[.control], [.shift], [.option, .shift], [.control, .shift, .option]] {
            let rejected = ShortcutChord.validate(keyCode: ShortcutChord.modifierOnlyKeyCode, modifiers: other,
                                                  keyLabel: "", modifierOnly: true, systemShortcuts: [])
            #expect(rejected == .failure(.needsModifier))
        }
        #expect(!ShortcutChord.suggested.isModifierOnly)
    }

    @Test func rejectsSystemShortcut() {
        let taken = ShortcutChord.Key(keyCode: 49, modifiers: [.control])
        let result = ShortcutChord.validate(keyCode: 49, modifiers: [.control], keyLabel: "Space", modifierOnly: false,
                                            systemShortcuts: [taken])
        #expect(result == .failure(.systemShortcut))
        #expect(en(ShortcutChord.Rejection.systemShortcut.message) == "macOS already uses this shortcut.")
    }

    @Test func acceptsSuggestedChord() {
        let result = ShortcutChord.validate(keyCode: 9, modifiers: [.control, .option], keyLabel: "V",
                                            modifierOnly: false, systemShortcuts: [])
        #expect(result == .success(.suggested))
        #expect(ShortcutChord.suggested.display == "⌃⌥V")
        #expect(vi("shortcut.useSuggestion", ShortcutChord.suggested.display) == "Dùng gợi ý: ⌃⌥V")
    }

    @Test func notArmedLineNamesTheReason() {
        let secure = makeStatus(availability: .standby(.secureInput), shortcutArmed: false)
        let reason = ShortcutNotice.notArmedReason(status: secure, configured: true)
        #expect(reason == LocalizedText("detail.secureInput"))
        #expect(vi("shortcut.notArmed", vi(reason!)).hasPrefix("Phím tắt hiện chưa dùng được:"))
        let noGrant = makeStatus(mode: .english, availability: .off, capabilities: .none)
        #expect(ShortcutNotice.notArmedReason(status: noGrant, configured: true) == LocalizedText("detail.accessibility"))
        #expect(ShortcutNotice.notArmedReason(status: noGrant, configured: false) == nil)
        let armed = makeStatus(availability: .active(.observed), shortcutArmed: true)
        #expect(ShortcutNotice.notArmedReason(status: armed, configured: true) == nil)
    }

    @Test func hudOnlyForShortcutModeChanges() {
        let english = makeStatus(mode: .english, availability: .off)
        let byShortcut = makeStatus(source: .shortcut, availability: .active(.observed))
        let byMenu = makeStatus(source: .menu, availability: .active(.observed))
        #expect(ModeHUDRule.shouldShow(previous: english, next: byShortcut))
        #expect(!ModeHUDRule.shouldShow(previous: english, next: byMenu))
        #expect(!ModeHUDRule.shouldShow(previous: byShortcut, next: byShortcut))
        #expect(!ModeHUDRule.shouldShow(previous: nil, next: byShortcut))
        #expect(vi(ModeHUDRule.text(for: .vietnamese)) == "Tiếng Việt")
        #expect(ModeHUDRule.fadeDuration(reduceMotion: true) == 0)
        #expect(ModeHUDRule.fadeDuration(reduceMotion: false) == 0.15)
        #expect(ModeHUDRule.displaySeconds == 0.8)
        // Setup's mode switch and the menu both send `menu`; neither shows the HUD.
        let fromSetup = makeStatus(source: .menu, availability: .active(.observed))
        #expect(!ModeHUDRule.shouldShow(previous: english, next: fromSetup))
    }
}

struct SettingsTabTests {
    @Test func appsTabListsTheProfileTableInMockupOrder() {
        let tab = AppsTab(catalog: .stub, excluded: ["com.apple.Safari"])
        #expect(tab.rows.map { vi($0.name) } == ["Chrome", "Safari", "Dia", "VS Code", "Ghi chú"])
        #expect(tab.rows.map(\.typesVietnamese) == [true, false, true, true, true])
        #expect(tab.rows[0].fields.map { vi($0.name) } == ["Ô chữ trên trang web", "Thanh địa chỉ"])
        #expect(tab.rows[3].fields.map { vi($0.name) } == ["Trình soạn thảo", "Tìm", "Ô lệnh nhanh"])
        // The label is evidence only: Find and Notes have none, and no row says "supported".
        #expect(tab.rows[3].fields.map { vi($0.state) } == ["Đã kiểm thử, kiểm tra giảm ⓘ", "Chưa kiểm thử", "Đã kiểm thử ✓"])
        #expect(tab.rows[4].fields.map { vi($0.state) } == ["Chưa kiểm thử"])
    }

    @Test func testedLabelFollowsTheProfile() {
        let catalog = ProfileCatalog(profiles: [
            .init(id: "chrome.webText", bundleID: "com.google.Chrome", field: .webText, tested: true),
        ])
        #expect(en(AppsTab(catalog: catalog, excluded: []).rows[0].fields[0].state) == "Tested ✓")
    }

    @Test func excludedAppOutsideTheListGetsARowWithoutFields() {
        let tab = AppsTab(catalog: .stub, excluded: ["com.tinyspeck.slackmacgap"])
        #expect(tab.rows.count == 6)
        #expect(tab.rows[5].bundleID == "com.tinyspeck.slackmacgap")
        #expect(tab.rows[5].fields.isEmpty)
        #expect(!tab.rows[5].typesVietnamese)
        #expect(tab.rows.prefix(5).map(\.typesVietnamese) == [true, true, true, true, true])
    }

    @Test func statusTabHasNoPostingRow() {
        let status = makeStatus(mode: .english, availability: .off,
                                capabilities: Capabilities(accessibility: true, eventListening: true, eventPosting: false),
                                inputSourceID: "x.Telex")
        let tab = StatusTab(status: status)
        #expect(tab.rows.map { vi($0.label) } == ["Theo dõi đầu vào", "Trợ năng", "Bàn phím"])
        #expect(tab.rows[2].action == .openKeyboardSettings)
        #expect(vi(tab.rows[2].value) == "Telex ✗")
        #expect(tab.rows[1].action == nil)
        #expect(StatusTab.technicalDetails(status: status).contains { $0 == ("eventPosting", "false") })
    }

    @Test func missingGrantRowOffersOpen() {
        let tab = StatusTab(status: makeStatus(mode: .english, availability: .off, capabilities: .none))
        #expect(tab.rows[0].action == .requestPermission(.inputMonitoring))
        #expect(tab.rows[1].action == .requestPermission(.accessibility))
        #expect(en(tab.rows[1].value) == "Off")
    }
}

struct ModifierTapDetectorTests {
    @Test func controlThenShiftThenReleaseFiresOnce() {
        var detector = ModifierTapDetector(target: [.control, .shift])
        let r1 = detector.modifiersChanged([.control])
        #expect(!r1)
        let r2 = detector.modifiersChanged([.control, .shift])
        #expect(!r2)
        let r3 = detector.modifiersChanged([.shift])
        #expect(!r3)
        let r4 = detector.modifiersChanged([])
        #expect(r4)
        let r5 = detector.modifiersChanged([])
        #expect(!r5)
    }

    @Test func aKeyOrClickWhileHeldCancels() {
        var detector = ModifierTapDetector(target: [.control, .shift])
        _ = detector.modifiersChanged([.control, .shift])
        detector.otherInput() // For example ⌃⇧T in a browser.
        let r6 = detector.modifiersChanged([])
        #expect(!r6)
    }

    @Test func anExtraModifierCancels() {
        var detector = ModifierTapDetector(target: [.control, .shift])
        _ = detector.modifiersChanged([.control, .shift])
        _ = detector.modifiersChanged([.control, .shift, .command])
        _ = detector.modifiersChanged([.control, .shift])
        let r7 = detector.modifiersChanged([])
        #expect(!r7)
    }

    @Test func oneModifierAloneDoesNotFire() {
        var detector = ModifierTapDetector(target: [.control, .shift])
        _ = detector.modifiersChanged([.control])
        let r8 = detector.modifiersChanged([])
        #expect(!r8)
    }

    @Test func aKeyBeforeTheGestureDoesNotCancelIt() {
        var detector = ModifierTapDetector(target: [.control, .shift])
        detector.otherInput()
        _ = detector.modifiersChanged([.shift])
        _ = detector.modifiersChanged([.control, .shift])
        let r9 = detector.modifiersChanged([])
        #expect(r9)
    }
}
