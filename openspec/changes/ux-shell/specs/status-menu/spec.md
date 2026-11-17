# Status menu

## Purpose

Show the current input state in the menu bar and give one next step when Vietnamese typing is not active. The menu is the complete control; the shortcut is a convenience.

## ADDED Requirements

### Requirement: Menu bar title states
The menu bar item SHALL show a fixed-width template title, `VI` in Vietnamese mode and `EN` in English mode. It SHALL add the badge that ux-spec section 5.1 assigns to the UI class: a pause badge for shown Standby reasons, a triangle for Blocked reasons, and a triangle in English mode only when a capability is missing. Quiet Standby reasons and word-level holds SHALL NOT change the title.

#### Scenario: Active Vietnamese
- **WHEN** the status is Vietnamese mode with availability `active`
- **THEN** the title is `VI` with no badge
- **AND** its accessibility label is `VietMac: tiếng Việt` or `VietMac: Vietnamese`

#### Scenario: English with a missing grant
- **WHEN** the mode is English and `capabilities.accessibility` is false
- **THEN** the title is `EN` with the triangle badge
- **AND** its accessibility label says a permission is off

#### Scenario: Click outside any text field
- **WHEN** availability changes from `active` to `standby(noTextField)` and back
- **THEN** the title stays `VI` with no badge throughout

### Requirement: Publication timing without flicker
The title SHALL apply a Blocked change, a mode change, and a change to Active within one run-loop pass after the status is published. It MAY delay adding or removing a Standby badge by up to 500 ms. The shell SHALL NOT open a window, play a sound, or post a notification because of a status change.

#### Scenario: Focus passes through an excluded app quickly
- **WHEN** availability goes `active` → `standby(excludedApp)` → `active` within 300 ms
- **THEN** the title shows no pause badge at any point

#### Scenario: Grant revoked while running
- **WHEN** the capability read for Accessibility turns false
- **THEN** the triangle badge appears in the same run-loop pass as the published status
- **AND** no window opens

### Requirement: Menu structure and one next step
The menu SHALL be a standard `NSMenu` that reads the current status when it opens and follows the item order in ux-spec section 5.3. When not Active, it SHALL show one detail line and at most one action item from the reason table. When several gates fail, it SHALL show only the first failing reason in gate order.

#### Scenario: Two gates fail
- **WHEN** Accessibility is missing and the input source is not ABC or U.S.
- **THEN** the menu shows only the Accessibility detail line and `Bật quyền Trợ năng…`

#### Scenario: Every reason has copy
- **WHEN** the simulator renders each Blocked and Standby reason in each UI language
- **THEN** each shows the detail line and action from ux-spec section 5.4
- **AND** none shows a raw enum name, the word "error" or "lỗi", or more than one action

#### Scenario: Conditional items
- **WHEN** the frontmost app has no field profile and setup is complete
- **THEN** the menu has no `Tắt tiếng Việt trong <App>` item and no `Tiếp tục thiết lập…` item

#### Scenario: Old developer items are gone
- **WHEN** the normal menu opens
- **THEN** it contains no `Enable M0 prototype` item, no ✓/✗ access row, and no example notice

### Requirement: Resume only for sticky reasons
The menu SHALL offer `Tiếp tục gõ tiếng Việt` / `Resume Vietnamese` only for `userDisabledTap`, `recoveryLimit`, and `transportUncertain`, and `Thử lại` / `Try Again` only for `tapUnavailable`. The action SHALL call `resume()`. The shell SHALL NOT offer "type anyway", resume automatically, or repair text.

#### Scenario: Transport uncertainty
- **WHEN** the status is `blocked(transportUncertain)`
- **THEN** the detail line tells the user to check the last word typed
- **AND** choosing the action calls `resume()` once and nothing else

#### Scenario: Tap creation fails twice
- **WHEN** `Thử lại` was chosen and the status is still `blocked(tapUnavailable)`
- **THEN** the action item becomes `Mở lại VietMac` / `Reopen VietMac`

### Requirement: Mode items and shortcut display
The radio items SHALL call `setMode` and SHALL work in every state. The menu SHALL show the configured chord beside the Vietnamese item only while `shortcutArmed` is true.

#### Scenario: Shortcut not armed
- **WHEN** a shortcut is configured and `shortcutArmed` is false
- **THEN** the mode items show no chord
- **AND** choosing a mode item still changes the mode

### Requirement: Per-app exclusion from the menu
The menu SHALL offer `Tắt tiếng Việt trong <App>` for every frontmost app that has a bundle ID (change `open-app-coverage`). Choosing it SHALL add that app's bundle ID to the stored exclusions and apply the new configuration. While the frontmost app is excluded, the item SHALL read `Bật lại tiếng Việt trong <App>` and remove the exclusion. Exclusions SHALL be per app, never per field.

#### Scenario: Exclude Chrome
- **WHEN** Chrome is frontmost and the user chooses `Tắt tiếng Việt trong Chrome`
- **THEN** the stored exclusions contain Chrome's bundle ID and the configuration is applied
- **AND** the item now reads `Bật lại tiếng Việt trong Chrome`

### Requirement: Mode HUD for shortcut changes
When a published status has a new mode and `modeSource == shortcut`, the shell SHALL show a non-activating HUD with `Tiếng Việt` or `Tiếng Anh` and the `VI` / `EN` glyph for 0.8 s, using the system HUD material. The HUD SHALL ignore mouse events, never become key, and post one VoiceOver announcement. With Reduce Motion on, it SHALL appear and disappear without a fade. A mode change from the menu or setup SHALL NOT show the HUD.

#### Scenario: Toggle with the shortcut
- **WHEN** the status changes from English to Vietnamese with `modeSource == shortcut`
- **THEN** the HUD shows once for 0.8 s and VoiceOver announces once
- **AND** the frontmost app keeps keyboard focus

#### Scenario: Toggle from the menu
- **WHEN** the mode changes with `modeSource == menu`
- **THEN** no HUD appears

### Requirement: Diagnostic report from the menu
Holding Option while the menu is open SHALL reveal `Lưu báo cáo chẩn đoán…` / `Save Diagnostic Report…`. The report SHALL contain only the "may show" fields of architecture-spec section 7.9 and SHALL be written only to a location the user chooses.

#### Scenario: Export a report
- **WHEN** the user holds Option, chooses the item, and picks a file location
- **THEN** the saved file contains status, capability, profile, and counter fields
- **AND** it contains no typed text, key identity, field value, title, or URL
