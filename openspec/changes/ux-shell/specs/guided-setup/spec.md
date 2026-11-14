# Guided setup

## Purpose

Take a new user from first launch to the first correct Vietnamese word without documentation, and explain later problems in the same window in Help mode.

## ADDED Requirements

### Requirement: Derived step list
The Setup window SHALL build its step list at runtime from settled unknowns and the status: Welcome; Input Monitoring only while the `listening` gate exists (U-2); Accessibility; Keyboard; Other input tool only when `conflictingBundleID` is set and U-9 has passed; Try it; Ready. The step indicator SHALL count only the steps in this list. A step whose condition already holds SHALL show a check mark.

#### Scenario: Input Monitoring is not needed
- **WHEN** the build records that the active tap does not need Input Monitoring
- **THEN** the step list has no Input Monitoring step and the indicator counts six steps

#### Scenario: No conflicting tool support yet
- **WHEN** U-9 has not passed
- **THEN** the Other input tool step never appears
- **AND** the Welcome step shows the line that asks the user to quit other Vietnamese input tools first

### Requirement: Setup completion is derived from status fields
Setup SHALL be complete when every required member of `capabilities` is true, `inputSourceID` is ABC or U.S., and `conflictingBundleID` is nil. The shell SHALL read these fields and SHALL NOT use `availability` for this decision. The shell SHALL store only the last step the user saw. On reopen, setup SHALL start at the first missing item in gate order.

#### Scenario: First launch in English mode
- **WHEN** the app launches for the first time with availability `off` and no grants
- **THEN** setup is incomplete and opens at the Welcome step

#### Scenario: Relaunch during setup
- **WHEN** the user relaunches after granting Input Monitoring but not Accessibility
- **THEN** setup opens at the Accessibility step, not at Welcome

### Requirement: Permission requests only from a click
On a grant step, the primary button SHALL call the matching system request function (`CGRequestListenEventAccess` or `AXIsProcessTrustedWithOptions` with the prompt option) and then open the matching System Settings pane. The shell SHALL NOT call a request function at launch, on a timer, from a status change, or from the key callback. Event posting SHALL NOT be presented as a separate switch to turn on.

#### Scenario: Click the Accessibility button
- **WHEN** the user clicks `Mở Cài đặt Hệ thống` on the Accessibility step
- **THEN** the request function runs once and the Accessibility pane opens

#### Scenario: Launch with missing grants
- **WHEN** the app launches with every grant missing
- **THEN** no request function runs and no system prompt appears before a click

### Requirement: Grant change feedback without auto-advance
When a capability read turns true, the step SHALL show `Đã bật ✓` within one run-loop pass of the published status, move keyboard focus to `Tiếp tục`, and announce the change to VoiceOver. The window SHALL come to the front only if it is already open and `frontmostBundleID` is System Settings. The step SHALL NOT advance by itself.

#### Scenario: Grant while System Settings is frontmost
- **WHEN** the user turns on Accessibility in System Settings and the read turns true
- **THEN** the setup window comes to the front with focus on `Tiếp tục`

#### Scenario: Grant while another app is frontmost
- **WHEN** the read turns true while a text editor is frontmost
- **THEN** the step updates but the window does not come to the front

### Requirement: Stale grant help and relaunch offer
Every grant step SHALL carry the stale-entry help disclosure from ux-spec section 4.3. When a capability is still missing 20 s after the user returns from System Settings, the step SHALL offer `Mở lại VietMac`, which relaunches the app; setup then reopens at the first missing item. No copy SHALL tell the user to turn a grant off while a capability reads true.

#### Scenario: Grant still missing after return
- **WHEN** the user returns from System Settings and the read stays false for 20 s
- **THEN** the step shows `Mở lại VietMac` as a secondary button

### Requirement: Input source step never switches the source
The Keyboard step SHALL show the localized name of the current input source and tell the user to select ABC. Its button SHALL open Keyboard › Input Sources. VietMac SHALL NOT switch the input source.

#### Scenario: Wrong source
- **WHEN** `inputSourceID` is a Vietnamese input source
- **THEN** the step names that source with ✗ and the instruction to select ABC
- **AND** the selected input source is unchanged after any action in the step

### Requirement: Try-it step with a Notes fallback
The Try it step SHALL show a Vietnamese mode switch that is off on arrival and calls `setMode`, the sample `tieengs Vieetj`, the expected result `tiếng Việt`, and the Telex strip. Until FG-5 is accepted and U-6 passes, the step SHALL use the Notes variant with `Mở Ghi chú`, `Chữ đã đổi`, and `Chữ chưa đổi`. Choosing `Chữ chưa đổi` SHALL show the current status line and its action. The copy SHALL name the correct result and SHALL NOT promise that VietMac will change the text.

#### Scenario: The text did not change
- **WHEN** the user chooses `Chữ chưa đổi` while the status is `blocked(unsupportedSource)`
- **THEN** the step shows the input-source detail line and `Mở cài đặt Bàn phím…`

### Requirement: Ready step keeps defaults
The Ready step SHALL show where the icon is, an empty shortcut recorder with `Dùng gợi ý: <chord>`, the `Mở VietMac khi đăng nhập` checkbox unchecked, and the click tip. Completing setup without changes SHALL leave the shortcut unset and login startup off.

#### Scenario: Finish with defaults
- **WHEN** the user presses `Xong` without touching any control
- **THEN** the stored shortcut is unset and login startup is not requested

### Requirement: When setup opens by itself
Setup SHALL open by itself only under the launch rules in ux-spec section 4.6: at step 1 on the first launch, once at the missing item on a manual launch, and never at a login-item launch. Until U-15 passes, a launch with a missing item after setup was completed SHALL show the window without activating the app. Closing the window SHALL leave `Tiếp tục thiết lập…` in the menu.

#### Scenario: Manual launch after an update lost a grant
- **WHEN** setup was completed before and the user opens VietMac from Spotlight with Accessibility missing
- **THEN** setup opens once at the Accessibility step with `Hãy bật lại quyền cho VietMac`

#### Scenario: Fallback before U-15
- **WHEN** U-15 has not passed and VietMac launches with a missing grant after setup was completed
- **THEN** the setup window is shown without activating VietMac
- **AND** the frontmost app keeps keyboard focus

### Requirement: Help mode
The same window SHALL open in Help mode from `Hướng dẫn…` with the pages `Bảng gõ Telex`, `Vì sao một từ không đổi`, `Ô mật khẩu`, `Quyền của VietMac`, and `Bộ gõ khác`. Each page SHALL have fewer than 120 words and no external link.

#### Scenario: Open help for a password pause
- **WHEN** the status is `standby(secureInput)` and the user chooses `Xem lý do…`
- **THEN** the window opens in Help mode on `Ô mật khẩu`
