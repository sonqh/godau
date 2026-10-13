# VietMac app host

This target builds a menu bar shell. It does not intercept keys or convert text.
The active OpenSpec change `macos-transport-spike` owns the next implementation.

Run `make app` to create `.artifacts/VietMac.app`.
The build does not launch, install, sign, or replace an input app.
Use a stable signing identity and location before native permission verification.
The current bundle identifier is a local development identity.

M0 adds the event tap, ordered transport, context reset policy, and permission UI.
Keep Core Graphics details in `Sources/VietMacPlatform` and application presentation in this directory.
