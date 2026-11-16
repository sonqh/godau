# UX shell: manual test guide

Son, run the checks below and record each result in the table at the end. A model test or a snapshot is not native evidence.

The guide covers the five screens on the approved design canvas:

- the menu bar states and the menu
- the paused menus
- Setup › Input Monitoring
- Setup › Try it
- Settings › Apps

It also covers Help, Settings › General and Status, the shortcut, and the mode HUD.

## Start here

Do these steps once before the first check. Every command runs in the repository root.

1. Check that the signing identity exists:

   ```sh
   security find-identity -v -p codesigning
   ```

   The output must list `"VietMac Local Signing"`. If it is missing, stop. Without it, each rebuild loses the macOS permissions that you grant.
2. Build both bundles with that identity:

   ```sh
   export VIETMAC_SIGNING_IDENTITY="VietMac Local Signing"
   make app-debug
   make app
   ```

   Each build ends with `Built and locally signed .artifacts/<bundle> (not launched or installed).`
3. Write down the commit of the build with `git rev-parse --short HEAD`. Put it in the Build column of the results table.
4. Quit every running VietMac. Use `Thoát VietMac` in its menu, then check with `pgrep -fl VietMac`. The output must be empty.
5. Select the ABC keyboard. VietMac pauses under Apple's Vietnamese Telex input source, and this Mac uses that source by default.
6. Open one bundle only, for the section you run:

   | Section | Bundle | Command |
   | --- | --- | --- |
   | A. Simulator checks | Debug | `open ".artifacts/VietMac Debug.app"` |
   | B. Live checks | Release | `open .artifacts/VietMac.app` |

   Do not run the Debug and the Release bundle at the same time. Two running bundles may replace the same keys twice (not tested).
7. Check that the app runs: `VI` or `EN` appears in the menu bar.

## Order of work

Run the checks in this order. The first group gives the most evidence for the open tasks.

1. B17: physical typing in Chrome, Safari, Dia, Notes, and VS Code Find.
2. B11: exclusion in Chrome.
3. B9 and B10: the shortcut, armed and not armed.
4. B2, B3, B6, and B7: the permission flow (ux-shell tasks 3.2, 3.3, and 3.4).
5. B1 and B5: fresh setup. These need a bundle with no grants, so run them last in the permission group.
6. B14 and B15: keyboard, VoiceOver, and appearance (ux-shell task 5.1).
7. Section A, then the remaining B checks.

Task 3.3 accepts B3 and B6 only after U-3 has a recorded safe result. Record the results anyway, and mark them as early in the Notes column.
Task 5.1 also asks for Reduce Motion (UX-20), both UI languages on a Vietnamese macOS, and a screenshot of every state.

## What the build can and cannot do

- Typing uses the full Telex composer (`VietMacCore/TelexComposer`) inside the M0 host and its field checks. This applies in VS Code, Chrome, Dia, Safari, and Notes.
- The composer runs before the M0 native gate closes. FG-2 deferred integration until that gate, but Son's goal of 2026-11-14 asked for a testable MVP.
- Native automation ran on 2026-11-14 in Chrome, Dia, and Safari. It used synthetic HID key events, not physical typing. 39 of 39 runs passed. The runs covered these cases:
  - the Telex scenarios
  - a 660-key workload at 45 ms per key
  - rollover and fast typing
  - selection, focus switch, and external edit
  - Command chords and address-bar completion
- Release callback own-work p99 was 74 to 103 µs. Repeated Safari runs passed 10 of 10 typed runs.
- Notes (body and title) passed with `scripts/native_notes.py` on 2026-11-14.
- Notes capitalizes the first word of a new line. If a replacement deletes that letter, VietMac puts it back in lowercase. Example: `as` at the start of a line.
- After a click or an app switch, the first word transforms at once (Son, 2026-11-15). After a click inside a word, the new letters form a word of their own. Letters typed right after ⌘Tab, before VietMac can read the new field, transform only if the field held nothing else. (Changed on 2026-11-15. Retest B17.)
- Address bars in Chrome, Dia, and Safari transform words even while a suggestion is shown (2026-11-16). Retest B17 in the address bar.
- The mode shortcut can be ⌃⇧ alone: press both, release both, with no other key. (Added on 2026-11-15. Retest B9.)
- FG-1 (Son, 2026-11-14): option C. The VS Code editor and Quick Open stay literal in v0.1.
- No field profile is accepted yet, so Settings › Apps shows `Chưa hỗ trợ` for every field. The mockup's `Hỗ trợ ✓` appears only after full-engine native acceptance.
- The mode shortcut is a system hot key, because M0 has no shortcut matching in the key callback. VietMac registers it only while `shortcutArmed` is true.
- `⌃⌥V` is a candidate shortcut. Its conflicts in the five apps are unknown (PD-1).
- Login startup uses `SMAppService.mainApp`. The result of registering a bundle under `.artifacts` is unknown (U-7). Turn login startup off after the test.

## Build reference

```sh
export VIETMAC_SIGNING_IDENTITY="VietMac Local Signing"   # trusted identity: grants survive rebuilds
make app-debug     # .artifacts/VietMac Debug.app: Simulator (Debug) submenu, bundle ID local.sonquach.vietmac.debug
make app           # .artifacts/VietMac.app: Release, no simulator
make snapshots     # .artifacts/ux-snapshots: every setup step, Help page, Settings tab, light and dark, VI and EN
```

- The Debug bundle has its own bundle ID. Its permissions and preferences are separate from the Release build. Each bundle needs its own grants.
- On 2026-11-15 both bundles were rebuilt from commit `7dbe773` with the `VietMac Local Signing` identity. Before that rebuild, the Debug bundle had an ad hoc signature.
- Without `VIETMAC_SIGNING_IDENTITY`, a build gets an ad hoc signature and loses its grants at every rebuild.
- `make snapshots` rebuilds the Debug bundle. It writes `menu-vi.txt` and `menu-en.txt`, which check A1 uses.
- To test the UI in English, set VietMac Debug to English in System Settings › General › Language & Region › Applications. You can also use `Simulator (Debug) › UI Language`.

## Reset to a fresh setup

B1 and the UX-1 to UX-3 checks need a bundle that has no grants and no saved setup progress.

1. Quit the bundle.
2. In System Settings › Privacy & Security, select the bundle in Input Monitoring and click −. Do the same in Accessibility.
3. Delete its preferences. For the Debug bundle, run `defaults delete local.sonquach.vietmac.debug`. For the Release bundle, run `defaults delete local.sonquach.vietmac`.
4. Open the bundle again.

## A. Simulator checks (no permissions needed)

1. Open `VietMac Debug.app`.
2. Close Setup if it opens.
3. Click `VI`/`EN` in the menu bar.
4. Open `Simulator (Debug) › Start Simulator`.

| ID | Steps | Expected |
| --- | --- | --- |
| A1 (UX-8) | `Availability` › each `blocked(...)` and `standby(...)` reason. Repeat with `UI Language › English` | Title `VI` with a triangle (blocked), a pause badge (shown standby), or no badge (`noTextField`, `fieldUnreadable`, `sleeping`). The menu shows the status line, one detail line, and at most one action, as in `menu-vi.txt` and `menu-en.txt` in the snapshots. No raw enum name, no "error" or "lỗi" |
| A2 | `off (English)`, then `Capabilities` › turn Accessibility off | Title `EN` with a triangle. Menu line `Bạn vẫn gõ được. Tiếng Việt chưa sẵn sàng.` `Tiếp tục thiết lập…` appears |
| A3 | `active(observed)` → `standby(unsupportedApp)` → `active(observed)` quickly | No pause badge flicker (500 ms delay) |
| A4 | `Frontmost App` › Chrome, `active(observed)`. Choose `Tắt tiếng Việt trong Chrome` | VietMac stores the exclusion. Settings › Apps shows Chrome unchecked. In simulator mode the status does not change by itself. Pick `standby(excludedApp)` to see `Bật lại tiếng Việt trong Chrome` |
| A5 | `blocked(tapUnavailable)`, choose `Thử lại` | The simulator stays blocked. The item becomes `Mở lại VietMac` |
| A6 | Hold Option with the menu open | `Lưu báo cáo chẩn đoán…` replaces `Hướng dẫn…` |
| A7 | `Shortcut Armed` on, then `Toggle Mode with Shortcut` | HUD `Tiếng Việt` / `Tiếng Anh` for 0.8 s in the lower third, no focus change. With Reduce Motion on, no fade. A mode change from the menu shows no HUD |
| A8 | `Reset Setup Progress`, then `Apply Launch Rules Now` | Setup opens at `Bước 1 / 6` (UX-1, simulated) |
| A9 | Setup with `Capabilities` changes: turn Input Monitoring on while on step 2 | The row turns `Đã bật ✓`. Focus moves to `Tiếp tục`. No auto-advance |
| A10 | `Input Source` › VietnameseTelex, open Setup step 4 | The step names the source with ✗ and says to select ABC. VietMac does not switch the source (UX-5) |

## B. Live checks with the M0 host

Choose `Use Live M0 Status` in the simulator submenu, or use the Release build.

| ID | Steps | Expected |
| --- | --- | --- |
| B1 (UX-1) | First start of a fresh build. Delete preferences with `defaults delete local.sonquach.vietmac.debug` | Setup opens at `Bước 1 / 6`. Title `EN` with a triangle. No permission prompt before a click |
| B2 (UX-2) | Step 2, click `Mở Cài đặt Hệ thống` | macOS lists VietMac in Input Monitoring and the pane opens |
| B3 (UX-3) | Turn the switch on in System Settings | Within 1 s the step shows `Đã bật ✓`. The window comes to the front only because System Settings is frontmost. Focus is on `Tiếp tục` |
| B4 | Return from System Settings without turning the switch on, wait 20 s | `Mở lại VietMac` appears as a secondary button |
| B5 (UX-4) | Quit during setup after step 2, open again | Setup opens at Accessibility, not at Welcome |
| B6 (UX-12) | With every grant on and Vietnamese on, turn Accessibility off | A triangle appears. The menu shows `Bật quyền Trợ năng…`. No window opens |
| B7 (UX-13) | After `Xong`, turn one grant off and open VietMac from Spotlight | Setup shows `Hãy bật lại quyền cho VietMac` and does not take keyboard focus from the frontmost app |
| B8 (UX-19) | Open VietMac again while it runs | Settings opens on the last tab. There is still one VietMac process |
| B9 (UX-22) | Settings › General › `Dùng gợi ý: ⌃⌥V`. With every grant on, press ⌃⌥V in Notes | The mode toggles once and the HUD shows once. A 2 s hold of the chord toggles once |
| B9b | Settings › General › click the recorder, press ⌃⇧ and release. In Notes, press ⌃⇧ and release. Then press ⌃⇧T in Chrome | The recorder shows `⌃⇧`. In Notes the mode toggles once and the HUD shows once. ⌃⇧T reopens a tab and does not toggle the mode |
| B9c | Click the recorder, press ⌥ alone and release | The recorder keeps the old value and shows `Thêm ⌘, ⌃ hoặc ⌥, và một phím khác. Hoặc chỉ dùng ⌃⇧.` |
| B10 (UX-22) | Turn one grant off (or focus a password field) and press ⌃⌥V | The mode does not change. The chord reaches the app. General shows `Phím tắt hiện chưa dùng được: …` |
| B11 (UX-15) | Vietnamese on in Chrome. Choose `Tắt tiếng Việt trong Chrome`. Type `cas` | `cas` stays literal. A pause badge shows. The menu reads `Bật lại tiếng Việt trong Chrome`. Other apps still change `cas` to `cá` |
| B16 (UX-6) | Setup › Thử gõ: turn on Tiếng Việt, open Notes, type a space, then `tieengs Vieetj` | `tiếng Việt` without underline. `Chữ đã đổi` shows the success line |
| B17 | Type `dduowngf nguowif hoafn khuyur thuowr quys gif` in each app: Chrome, Safari, Dia, Notes, and VS Code Find | `đường người hoàn khuỷu thuở quý gì`. The VS Code editor stays literal (U-1) |
| B12 (UX-16) | General › `Mở VietMac khi đăng nhập` on, then off | The line below shows the system state, including approval needed |
| B13 | Settings › Status | Rows for Input Monitoring, Accessibility, Keyboard, and Version with the ad hoc warning. Posting appears only under `Chi tiết kỹ thuật` |
| B14 (UX-17) | Use Setup and Settings with the keyboard only and with VoiceOver | You can reach every control, and each control has a name. Esc acts as `Để sau` in Setup and closes Settings and Help |
| B15 (UX-18, UX-25) | Light and dark, Increase Contrast, Reduce Transparency, both Liquid Glass ends, menu bar background on and off | Every title, badge, and window text stays readable |

## After the test

1. Turn off `Mở VietMac khi đăng nhập` if you turned it on (U-7).
2. Quit VietMac with `Thoát VietMac`.
3. Select your usual input source again (Apple Vietnamese Simple Telex).

## Results

Write one row for each check. Result is `pass`, `fail`, or `partial`. For `fail` and `partial`, write the step that went wrong and what you saw in Notes. Do not paste private text that you typed.

| ID | Result | Build (commit, Debug or Release) | macOS | App and field | Notes |
| --- | --- | --- | --- | --- | --- |
| B17 | fail | `7dbe773`, Release | 27.0.1 | Notes, note body | 2026-11-15. `Tieengs Vieetj` gave `Tieengs Việt`. The first word stayed literal with and without a click before typing. Same result in Chrome: `Hayx` at the start of a prompt field stayed literal |
| B17 (outside scope) | fail | `7dbe773`, Release | 27.0.1 | VS Code, Claude extension prompt (webview) | 2026-11-15. Some words stayed literal in the middle of a sentence, for example `Truowngf`, `dduowjc`, `suwr`, `ddang`, while nearby words changed. Not one of the five accepted fields. FG-1 keeps the VS Code editor literal |
| B9 (Setup step 6) | fail | `7dbe773`, Release | 27.0.1 | VietMac Setup, step 6 | 2026-11-15. Son pressed ⌃⇧ (modifier only). The spec rejects this gesture, but the recorder showed no message: it listens to key-down events only, so it never sees a modifier-only gesture |
| B17 (address bar) | pass | `f180902`, Release | 27.0.1 | Chrome, Dia, Safari address bars | 2026-11-16. Physical typing: `dd`, `oo`, `as` transform while a suggestion is shown |
| B12 (Setup step 6) | known limit | `7dbe773`, Release | 27.0.1 | VietMac Setup, step 6 | 2026-11-15. The login line says `macOS cannot find VietMac to register it.` Expected while the bundle is under `.artifacts` (U-7) |
