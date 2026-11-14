# VietMac app host

This target presents the M0 native transport host with the complete Telex composer. It starts in English mode.
When Vietnamese is on with all capabilities and a supported inspected context, it replaces the tracked word as Telex specifies.
Native acceptance of the five apps is still pending; see the manual test guide.

Run `make app` to create `.artifacts/VietMac.app`.
The build signs locally with ad hoc signing by default; it does not launch, install, or replace an input app.
Set `VIETMAC_SIGNING_IDENTITY` explicitly to use a chosen existing identity. No certificate or trust setting is created automatically.
Use a stable signing identity and location before native permission verification.
The current bundle identifier is a local development identity.
Ad hoc signing verifies bundle integrity but does not promise permission continuity across rebuilt binaries.
On 2026-10-14 a build signed with an untrusted self-signed certificate received no Accessibility or Input Monitoring capability after Son re-added it. Ad hoc grants worked but are tied to one CDHash.
Keep the same signed build at this location during a native acceptance session; record its identity and enabled capabilities.

The menu bar item shows `VI` or `EN` with a template badge, as specified in the `ux-shell` change.
The status menu shows one status line, one detail line, and at most one next step. Choose `Tiếng Việt` / `Vietnamese` to enable the M0 prototype and `Tiếng Anh` / `English` to disable it.
`Tắt tiếng Việt trong <App>` excludes one of the five trial apps; an excluded app passes every key through.
Hold Option in the open menu to reveal `Save Diagnostic Report…`, which exports diagnostics and callback timings to a file you choose.
`M0StatusAdapter` maps the M0 host state into `RuntimeStatus` until `telex-input-mvp` M2 supplies the real status.
The Setup and Help window opens from the menu and by itself only under the launch rules of ux-spec 4.6. Its grant buttons call the system request function and then open the System Settings pane; nothing requests a permission at launch, on a timer, or from the menu.
Settings has General (shortcut recorder, login startup), Apps (the profile table; no profile is accepted yet), and Status tabs. Opening VietMac again while it runs opens Settings.
The optional mode shortcut is a system hot key registered only while it is armed; a shortcut change shows the mode HUD.
`make app-debug` builds `VietMac Debug.app` with a `Simulator (Debug)` submenu. `make snapshots` renders every screen to `.artifacts/ux-snapshots`. `make app` builds Release, which has neither.
See [the manual test guide](../../docs/verification/ux-shell-manual-test.md).

UX criteria that stay with `telex-input-mvp` (they need the full M2 runtime or native acceptance): UX-6 (try-it typing), UX-7 mode part, UX-9 to UX-11 (title timing in real apps, word-level holds, shortcut press with VoiceOver and focus), UX-14 (`transportUncertain` in the field), UX-15 (exclusion in real typing), UX-16 (login registration states), UX-19 (single instance), UX-21 (report contents after typing), UX-23 (login-item launch), and UX-24 (profile table after acceptance).
Native ux-shell checks still open: UX-2 (task 3.2), UX-3 and UX-12 (task 3.3), UX-13 (task 3.4), and UX-17, UX-18, UX-20, UX-25 (task 5.1).
Opening settings does not grant permissions. Son must enable Accessibility and Input Monitoring for this bundle manually.
Do not run another Vietnamese event-transforming app during native acceptance; keep the input source at ABC or U.S.

```sh
.artifacts/VietMac.app/Contents/MacOS/VietMac --diagnostics
```

Diagnostics exits without an event tap or permission prompt and identifies the capability state of the invoked process.
A successful command is not proof of a Launch Services app session or native input.

```sh
open .artifacts/VietMac.app --args --evidence-dir "$PWD/.artifacts/native/session-1"
kill -USR1 "$(pgrep -f 'VietMac.app/Contents/MacOS/VietMac')"
```

`--evidence-dir` takes an absolute path. The running app writes `session-diagnostics.json` (capabilities, state, tap, context counters) and `callback-timings.json` at launch and on `SIGUSR1`, outside the key callback.
Timing export contains only bounded duration samples and environment metadata, without typed text.
Zero samples and Debug captures are not Release callback performance evidence.

Use [the synthetic browser fields](../../Fixtures/native-fields.html) and [the M0 native matrix](../../docs/verification/macos-transport-spike.md).
Do not test the prototype against real documents before its required native acceptance passes.

M0 acceptance is still pending. Caret/length metadata does not acknowledge document edits; a same-length same-caret programmatic change remains undetectable.
Keep Core Graphics details in `Sources/VietMacPlatform` and application presentation in this directory.
