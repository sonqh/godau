# Settings window

## Purpose

Give one place to change the few preferences VietMac has, see which apps and field kinds are supported, and read the current permission state.

## ADDED Requirements

### Requirement: Three tabs in a standard Settings window
The Settings window SHALL open from `Cài đặt…`, from ⌘, and when VietMac is opened again while it runs. It SHALL have the toolbar tabs `Chung` / `General`, `Ứng dụng` / `Apps`, and `Trạng thái` / `Status`, remember the last tab, and change nothing when closed.

#### Scenario: Reopen from Spotlight
- **WHEN** VietMac is running and the user opens it again from Spotlight
- **THEN** the Settings window opens on the last tab used

### Requirement: Shortcut recorder with rules
The General tab SHALL show a shortcut recorder with `Xoá` and `Dùng gợi ý: <chord>`. The recorder SHALL reject a chord without Command, Control, or Option, a modifier-only gesture, and a chord that matches a system shortcut, with the copy from ux-spec section 6.2. While a shortcut is set and `shortcutArmed` is false, the tab SHALL show the not-armed line with the current reason.

#### Scenario: Reject a plain letter
- **WHEN** the user records `V` with no modifier
- **THEN** the recorder keeps the old value and shows `Thêm ⌘, ⌃ hoặc ⌥, và một phím khác.`

#### Scenario: Shortcut blocked by secure input
- **WHEN** a shortcut is set and the status shows `standby(secureInput)` with `shortcutArmed` false
- **THEN** the tab shows `Phím tắt hiện chưa dùng được:` with the secure-input reason

### Requirement: Login startup shows the system state
The General tab SHALL show the `Mở VietMac khi đăng nhập` checkbox, off by default, and below it the registration state reported by the system, read when the window opens or becomes key and after each change. It SHALL show `requiresApproval` with an `Mở` button to System Settings › Login Items.

#### Scenario: Approval needed
- **WHEN** the user checks the box and the system reports `requiresApproval`
- **THEN** the tab shows the approval line and `Mở`
- **AND** it does not show `Đã bật`

### Requirement: Apps tab from the profile table
The Apps tab SHALL list one row per supported app from the compiled field-profile table, with the field kinds the runtime can tell apart and a state label per kind: `Hỗ trợ ✓` for an accepted `observed` profile and `Chưa hỗ trợ` otherwise. Each row SHALL have a `Gõ tiếng Việt` checkbox, on unless the app is excluded. The tab SHALL NOT claim support for all websites or all fields, and SHALL NOT scan installed apps.

#### Scenario: VS Code before FG-1
- **WHEN** the profile table has no accepted `vscode.editor` or `vscode.quickInput` profile
- **THEN** the VS Code editor and Quick Open rows show `Chưa hỗ trợ`

#### Scenario: Uncheck an app
- **WHEN** the user unchecks `Gõ tiếng Việt` for Safari
- **THEN** Safari's bundle ID is added to the exclusions and the configuration is applied

### Requirement: Status tab without a posting switch
The Status tab SHALL show the rows in ux-spec section 7.2, each with `Mở…` when an action exists, and a collapsed `Chi tiết kỹ thuật` disclosure with the technical fields and `Lưu báo cáo chẩn đoán…`. Event posting SHALL appear only inside that disclosure. An ad hoc signed build SHALL show the rebuild warning in the Version row.

#### Scenario: Posting is not a switch
- **WHEN** `capabilities.eventPosting` is false
- **THEN** no Status row offers to turn posting on
- **AND** the disclosure lists the posting read with the other capability reads

#### Scenario: Ad hoc build
- **WHEN** the diagnostics report `signature == adHoc`
- **THEN** the Version row shows `Bản dựng này mất quyền sau mỗi lần dựng lại.`
