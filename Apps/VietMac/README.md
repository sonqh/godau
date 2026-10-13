# VietMac app host

This target presents the M0 native transport prototype. It starts disabled.
When explicitly enabled with all capabilities and a supported inspected context, it intercepts keys for `as` → `á` and `aa` → `â` only.
This is not the complete Telex engine, and native compatibility remains unverified.

Run `make app` to create `.artifacts/VietMac.app`.
The build signs locally with ad hoc signing by default; it does not launch, install, or replace an input app.
Set `VIETMAC_SIGNING_IDENTITY` explicitly to use a chosen existing identity. No certificate or trust setting is created automatically.
Use a stable signing identity and location before native permission verification.
The current bundle identifier is a local development identity.
Ad hoc signing verifies bundle integrity but does not promise permission continuity across rebuilt binaries.
Keep the same signed build at this location during a native acceptance session; record its identity and enabled capabilities.

The menu exposes enable/disable, explicit resume after a pause, read-only capability status, system-settings links, and timing export.
Opening settings does not grant permissions. Son must enable Accessibility and Input Monitoring for this bundle manually.
Do not run another Vietnamese event-transforming app during native acceptance; keep the input source at ABC or U.S.

```sh
.artifacts/VietMac.app/Contents/MacOS/VietMac --diagnostics
```

Diagnostics exits without an event tap or permission prompt and identifies the capability state of the invoked process.
A successful command is not proof of a Launch Services app session or native input.
Timing export contains only bounded duration samples and environment metadata, without typed text.
Zero samples and Debug captures are not Release callback performance evidence.

Use [the synthetic browser fields](../../Fixtures/native-fields.html) and [the M0 native matrix](../../docs/verification/macos-transport-spike.md).
Do not test the prototype against real documents before its required native acceptance passes.

M0 acceptance is still pending. In particular, cached focus/caret metadata does not acknowledge document edits or guarantee detection of same-caret programmatic changes.
Keep Core Graphics details in `Sources/VietMacPlatform` and application presentation in this directory.
