import Testing
import VietMacPlatform
@testable import VietMacShell

private let vi = Strings(language: .vi)
private let en = Strings(language: .en)

struct ShortcutChordTests {
    @Test func rejectsPlainLetterAndModifierOnly() {
        let plain = ShortcutChord.validate(keyCode: 9, modifiers: [], keyLabel: "V", modifierOnly: false, systemShortcuts: [])
        #expect(plain == .failure(.needsModifier))
        #expect(vi(ShortcutChord.Rejection.needsModifier.message) == "Thêm ⌘, ⌃ hoặc ⌥, và một phím khác.")
        let shiftOnly = ShortcutChord.validate(keyCode: 9, modifiers: [.shift], keyLabel: "V", modifierOnly: false,
                                               systemShortcuts: [])
        #expect(shiftOnly == .failure(.needsModifier))
        let gesture = ShortcutChord.validate(keyCode: 58, modifiers: [.option], keyLabel: "", modifierOnly: true,
                                             systemShortcuts: [])
        #expect(gesture == .failure(.needsModifier))
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
    }
}

struct SettingsTabTests {
    @Test func appsTabListsTheProfileTableInMockupOrder() {
        let tab = AppsTab(catalog: .stub, excluded: ["com.apple.Safari"])
        #expect(tab.rows.map { vi($0.name) } == ["Chrome", "Safari", "Dia", "VS Code", "Ghi chú"])
        #expect(tab.rows.map(\.typesVietnamese) == [true, false, true, true, true])
        #expect(tab.rows[0].fields.map { vi($0.name) } == ["Ô chữ trên trang web", "Thanh địa chỉ"])
        #expect(tab.rows[3].fields.map { vi($0.name) } == ["Trình soạn thảo", "Tìm", "Ô lệnh nhanh"])
        // No profile is accepted yet, so no row claims support (UX-24).
        #expect(tab.rows.allSatisfy { $0.fields.allSatisfy { vi($0.state) == "Chưa hỗ trợ" } })
    }

    @Test func acceptedProfileShowsSupported() {
        let catalog = ProfileCatalog(profiles: [
            .init(id: "chrome.webText", bundleID: "com.google.Chrome", field: .webText, accepted: true),
        ])
        #expect(en(AppsTab(catalog: catalog, excluded: []).rows[0].fields[0].state) == "Supported ✓")
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
